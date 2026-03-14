#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
LIB_DIR="$SCRIPT_DIR/../scripts/lib"

echo "  Content-aware fingerprint tests"

setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_WINDOW_SIZE=20
export HB_LOOP_THRESHOLD=3
export HB_ERROR_THRESHOLD=5
export HB_CONTEXT_PCT=80
export HB_CONTEXT_WINDOW_BYTES=4000000
export HB_MAX_NUDGES=3
export HB_DRY_RUN=0
export HB_ALLOWLIST=""
source "$LIB_DIR/config.sh"
source "$LIB_DIR/state.sh"
source "$LIB_DIR/detect.sh"

run_test "fingerprint includes content hash when provided"
init_state "test-fp-001"
append_tool_call "Edit" "src/auth.ts" 100 "12345"
fp="$(jq -r '.tool_calls[0].fingerprint' "$HB_STATE_DIR/state.json")"
assert_contains "$fp" "Edit:src/auth.ts:12345" "fingerprint has content hash"

run_test "fingerprint omits hash when empty"
init_state "test-fp-002"
append_tool_call "Read" "src/auth.ts" 100 ""
fp="$(jq -r '.tool_calls[0].fingerprint' "$HB_STATE_DIR/state.json")"
assert_contains "$fp" "Read:src/auth.ts" "fingerprint without hash"

run_test "fingerprint omits hash when not provided (backward compat)"
init_state "test-fp-003"
append_tool_call "Read" "src/auth.ts" 100
fp="$(jq -r '.tool_calls[0].fingerprint' "$HB_STATE_DIR/state.json")"
assert_contains "$fp" "Read:src/auth.ts" "fingerprint backward compat"

run_test "different content hashes produce different fingerprints"
init_state "test-fp-004"
append_tool_call "Edit" "src/auth.ts" 100 "hash_a"
append_tool_call "Edit" "src/auth.ts" 100 "hash_b"
append_tool_call "Edit" "src/auth.ts" 100 "hash_c"
result="$(detect_loop)"
assert_contains "$result" "none" "different hashes = no loop"

run_test "same content hash triggers loop detection"
init_state "test-fp-005"
append_tool_call "Edit" "src/auth.ts" 100 "same_hash"
append_tool_call "Edit" "src/auth.ts" 100 "same_hash"
append_tool_call "Edit" "src/auth.ts" 100 "same_hash"
result="$(detect_loop)"
assert_contains "$result" "edit-undo-cycle" "same hash = loop detected"

run_test "mixed hashes below threshold no loop"
init_state "test-fp-006"
append_tool_call "Edit" "src/auth.ts" 100 "hash_a"
append_tool_call "Edit" "src/auth.ts" 100 "hash_b"
append_tool_call "Edit" "src/auth.ts" 100 "hash_a"
result="$(detect_loop)"
assert_contains "$result" "none" "2 of same hash below threshold 3"

run_test "allowlist with wildcard works on content-aware fingerprints"
init_state "test-fp-007"
export HB_ALLOWLIST="Edit:src/auth.ts:*"
source "$LIB_DIR/detect.sh"
append_tool_call "Edit" "src/auth.ts" 100 "same_hash"
append_tool_call "Edit" "src/auth.ts" 100 "same_hash"
append_tool_call "Edit" "src/auth.ts" 100 "same_hash"
result="$(detect_loop)"
assert_contains "$result" "none" "allowlist with wildcard works on content-aware fp"
export HB_ALLOWLIST=""

# --- Integration tests via real hook ---

run_test "post-tool-use computes content hash for Edit"
init_state "test-fp-hook-001"
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/auth.ts","old_string":"const x = 1","new_string":"const x = 2"},"tool_output":"ok"}' \
  | bash "$SCRIPT_DIR/../scripts/post-tool-use.sh" 2>/dev/null
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/auth.ts","old_string":"const y = 1","new_string":"const y = 2"},"tool_output":"ok"}' \
  | bash "$SCRIPT_DIR/../scripts/post-tool-use.sh" 2>/dev/null
fp1="$(jq -r '.tool_calls[0].fingerprint' "$HB_STATE_DIR/state.json")"
fp2="$(jq -r '.tool_calls[1].fingerprint' "$HB_STATE_DIR/state.json")"
if [[ "$fp1" != "$fp2" ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: different old_strings should produce different fingerprints"
  echo "  Got: fp1=$fp1 fp2=$fp2"
fi

run_test "post-tool-use same Edit input produces same fingerprint"
init_state "test-fp-hook-002"
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/auth.ts","old_string":"const x = 1","new_string":"const x = 2"},"tool_output":"ok"}' \
  | bash "$SCRIPT_DIR/../scripts/post-tool-use.sh" 2>/dev/null
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/auth.ts","old_string":"const x = 1","new_string":"const x = 99"},"tool_output":"ok"}' \
  | bash "$SCRIPT_DIR/../scripts/post-tool-use.sh" 2>/dev/null
fp1="$(jq -r '.tool_calls[0].fingerprint' "$HB_STATE_DIR/state.json")"
fp2="$(jq -r '.tool_calls[1].fingerprint' "$HB_STATE_DIR/state.json")"
if [[ "$fp1" == "$fp2" ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: same old_string should produce same fingerprint regardless of new_string"
  echo "  Got: fp1=$fp1 fp2=$fp2"
fi

run_test "post-tool-use non-Edit tools have no content hash"
init_state "test-fp-hook-003"
echo '{"tool_name":"Bash","tool_input":{"command":"npm test"},"tool_output":"ok"}' \
  | bash "$SCRIPT_DIR/../scripts/post-tool-use.sh" 2>/dev/null
fp="$(jq -r '.tool_calls[0].fingerprint' "$HB_STATE_DIR/state.json")"
assert_contains "$fp" "Bash:npm test" "Bash fingerprint unchanged"
# Verify no content hash appended (should be exactly "Bash:npm test" with no extra colon)
colon_count="$(echo "$fp" | tr -cd ':' | wc -c | tr -d ' ')"
if [[ "$colon_count" -eq 1 ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: Bash fingerprint should have exactly 1 colon, got $colon_count in '$fp'"
fi

teardown_test_env
print_summary
