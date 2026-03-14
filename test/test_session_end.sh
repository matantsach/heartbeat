#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "  SessionEnd hook tests"

HOOK="$SCRIPT_DIR/../scripts/session-end.sh"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"

LIB_DIR="$SCRIPT_DIR/../scripts/lib"
export HB_WINDOW_SIZE=20
export HB_LOOP_THRESHOLD=3
export HB_ERROR_THRESHOLD=5
export HB_CONTEXT_PCT=80
export HB_CONTEXT_WINDOW_BYTES=4000000
export HB_MAX_NUDGES=3
source "$LIB_DIR/config.sh"
source "$LIB_DIR/state.sh"

run_test "prints clean session summary"
init_state "test-end-001"
append_tool_call "Edit" "file.ts" 100
append_tool_call "Bash" "npm test" 200
output="$(echo '{"session_id":"test-end-001","hook_event_name":"Stop"}' | bash "$HOOK" 2>&1)"
assert_contains "$output" "Heartbeat:" "starts with Heartbeat:"
assert_contains "$output" "2 tool calls" "shows tool count"
assert_contains "$output" "no issues" "clean session"

run_test "prints summary with interventions"
init_state "test-end-002"
append_tool_call "Edit" "file.ts" 100
jq '.intervention_count = 2 | .total_tool_calls = 47' "$HB_STATE_DIR/state.json" > "$HB_STATE_DIR/state.json.tmp" \
  && mv "$HB_STATE_DIR/state.json.tmp" "$HB_STATE_DIR/state.json"
output="$(echo '{"session_id":"test-end-002","hook_event_name":"Stop"}' | bash "$HOOK" 2>&1)"
assert_contains "$output" "47 tool calls" "shows total"
assert_contains "$output" "2 interventions" "shows intervention count"

run_test "session-end removes sentinel and PID file"
init_state "test-end-sentinel"
touch "$HB_STATE_DIR/.alive"
echo "99999" > "$HB_STATE_DIR/.timer_pid"
echo '{"hook_event_name":"Stop"}' | bash "$HOOK" 2>&1 >/dev/null
if [[ ! -f "$HB_STATE_DIR/.alive" ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: sentinel file should be removed"
fi
if [[ ! -f "$HB_STATE_DIR/.timer_pid" ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: timer PID file should be removed"
fi

teardown_test_env
print_summary
