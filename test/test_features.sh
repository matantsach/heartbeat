#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "  v0.2 Feature tests"

LIB_DIR="$SCRIPT_DIR/../scripts/lib"
PATTERNS_DIR="$SCRIPT_DIR/../patterns"

# ── Feature 1: Named Pattern Files ──────────────────────────────────────────

run_test "pattern files exist"
assert_file_exists "$PATTERNS_DIR/edit-undo-cycle.json" "edit-undo-cycle.json"
assert_file_exists "$PATTERNS_DIR/grep-spiral.json" "grep-spiral.json"
assert_file_exists "$PATTERNS_DIR/permission-hammer.json" "permission-hammer.json"
assert_file_exists "$PATTERNS_DIR/error-cascade.json" "error-cascade.json"
assert_file_exists "$PATTERNS_DIR/context-cliff.json" "context-cliff.json"

run_test "pattern files have required fields"
for pat in edit-undo-cycle grep-spiral permission-hammer error-cascade context-cliff; do
  name="$(jq -r '.name' "$PATTERNS_DIR/${pat}.json")"
  assert_contains "$name" "$pat" "${pat}.json name field"
done

run_test "get_nudge_message loads from pattern file"
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

init_state "test-feat-001"
append_tool_call "Edit" "src/auth.ts" 100
msg="$(get_nudge_message "edit-undo-cycle")"
assert_contains "$msg" "Edit-Undo Cycle" "display_name from pattern file"
assert_contains "$msg" "fundamentally different approach" "nudge text from pattern file"
teardown_test_env

run_test "get_nudge_message loads from user custom pattern directory"
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

init_state "test-feat-custom"
append_tool_call "Bash" "rm -rf /" 100
mkdir -p "$HB_STATE_DIR/patterns"
cat > "$HB_STATE_DIR/patterns/custom-pattern.json" <<'EOF'
{
  "name": "custom-pattern",
  "display_name": "My Custom Pattern",
  "nudge": "Custom nudge message here.",
  "severity": "low"
}
EOF
msg="$(get_nudge_message "custom-pattern")"
assert_contains "$msg" "My Custom Pattern" "custom display_name"
assert_contains "$msg" "Custom nudge message" "custom nudge text"
teardown_test_env

run_test "get_nudge_message falls back to hardcoded for unknown pattern"
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

init_state "test-feat-fallback"
append_tool_call "Edit" "file.ts" 100
msg="$(get_nudge_message "loop-detected")"
assert_contains "$msg" "Loop detected" "fallback hardcoded message used"
teardown_test_env

run_test "nudge placeholders are substituted"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_WINDOW_SIZE=20
export HB_LOOP_THRESHOLD=5
export HB_ERROR_THRESHOLD=5
export HB_CONTEXT_PCT=90
export HB_CONTEXT_WINDOW_BYTES=4000000
export HB_MAX_NUDGES=3
export HB_DRY_RUN=0
export HB_ALLOWLIST=""
source "$LIB_DIR/config.sh"
source "$LIB_DIR/state.sh"
source "$LIB_DIR/detect.sh"

init_state "test-feat-placeholder"
append_tool_call "Edit" "my-file.ts" 100
msg="$(get_nudge_message "edit-undo-cycle")"
assert_contains "$msg" "5+" "threshold placeholder replaced"
assert_contains "$msg" "my-file.ts" "target placeholder replaced"
teardown_test_env

# ── Feature 2: Dry-Run Mode ──────────────────────────────────────────────────

run_test "dry-run: intervention detected but not blocked"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_WINDOW_SIZE=20
export HB_LOOP_THRESHOLD=3
export HB_ERROR_THRESHOLD=5
export HB_CONTEXT_PCT=80
export HB_CONTEXT_WINDOW_BYTES=4000000
export HB_MAX_NUDGES=3
export HB_DRY_RUN=1
source "$LIB_DIR/config.sh"
source "$LIB_DIR/state.sh"

HOOK="$SCRIPT_DIR/../scripts/pre-tool-use.sh"
init_state "test-dry-001"
set_intervention "edit-undo-cycle" "You've been looping."
output="$(echo '{}' | HB_DRY_RUN=1 bash "$HOOK" 2>&1)" && exit_code=$? || exit_code=$?
assert_exit 0 "$exit_code" "dry-run exits 0 (no block)"
teardown_test_env

run_test "dry-run: intervention count incremented"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_WINDOW_SIZE=20
export HB_LOOP_THRESHOLD=3
export HB_ERROR_THRESHOLD=5
export HB_CONTEXT_PCT=80
export HB_CONTEXT_WINDOW_BYTES=4000000
export HB_MAX_NUDGES=3
export HB_DRY_RUN=1
source "$LIB_DIR/config.sh"
source "$LIB_DIR/state.sh"

HOOK="$SCRIPT_DIR/../scripts/pre-tool-use.sh"
init_state "test-dry-002"
set_intervention "edit-undo-cycle" "You've been looping."
echo '{}' | HB_DRY_RUN=1 bash "$HOOK" 2>/dev/null || true
count="$(get_state_field '.intervention_count')"
assert_contains "$count" "1" "dry-run increments intervention count"
teardown_test_env

run_test "dry-run: flag cleared after dry-run detection"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_WINDOW_SIZE=20
export HB_LOOP_THRESHOLD=3
export HB_ERROR_THRESHOLD=5
export HB_CONTEXT_PCT=80
export HB_CONTEXT_WINDOW_BYTES=4000000
export HB_MAX_NUDGES=3
export HB_DRY_RUN=1
source "$LIB_DIR/config.sh"
source "$LIB_DIR/state.sh"

HOOK="$SCRIPT_DIR/../scripts/pre-tool-use.sh"
init_state "test-dry-003"
set_intervention "edit-undo-cycle" "Loop message."
echo '{}' | HB_DRY_RUN=1 bash "$HOOK" 2>/dev/null || true
flag="$(get_state_field '.intervention')"
assert_contains "$flag" "null" "dry-run clears intervention flag"
teardown_test_env

run_test "session-end shows (dry-run) suffix"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_WINDOW_SIZE=20
export HB_LOOP_THRESHOLD=3
export HB_ERROR_THRESHOLD=5
export HB_CONTEXT_PCT=80
export HB_CONTEXT_WINDOW_BYTES=4000000
export HB_MAX_NUDGES=3
source "$LIB_DIR/config.sh"
source "$LIB_DIR/state.sh"

init_state "test-dry-end"
output="$(echo '{}' | HB_DRY_RUN=1 bash "$SCRIPT_DIR/../scripts/session-end.sh" 2>&1)"
assert_contains "$output" "dry-run" "session-end shows (dry-run)"
teardown_test_env

# ── Feature 3: Allowlisted Patterns ─────────────────────────────────────────

run_test "allowlist: exact fingerprint skips detection"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_WINDOW_SIZE=20
export HB_LOOP_THRESHOLD=3
export HB_ERROR_THRESHOLD=5
export HB_CONTEXT_PCT=80
export HB_CONTEXT_WINDOW_BYTES=4000000
export HB_MAX_NUDGES=3
export HB_DRY_RUN=0
export HB_ALLOWLIST="Edit:src/auth.ts"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/state.sh"
source "$LIB_DIR/detect.sh"

init_state "test-allow-001"
append_tool_call "Edit" "src/auth.ts" 100
append_tool_call "Edit" "src/auth.ts" 100
append_tool_call "Edit" "src/auth.ts" 100
result="$(detect_loop)"
assert_contains "$result" "none" "allowlisted fingerprint not flagged"
teardown_test_env

run_test "allowlist: non-allowlisted fingerprint still detected"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_WINDOW_SIZE=20
export HB_LOOP_THRESHOLD=3
export HB_ERROR_THRESHOLD=5
export HB_CONTEXT_PCT=80
export HB_CONTEXT_WINDOW_BYTES=4000000
export HB_MAX_NUDGES=3
export HB_DRY_RUN=0
export HB_ALLOWLIST="Edit:src/other.ts"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/state.sh"
source "$LIB_DIR/detect.sh"

init_state "test-allow-002"
append_tool_call "Edit" "src/auth.ts" 100
append_tool_call "Edit" "src/auth.ts" 100
append_tool_call "Edit" "src/auth.ts" 100
result="$(detect_loop)"
assert_contains "$result" "edit-undo-cycle" "non-allowlisted fingerprint detected"
teardown_test_env

run_test "allowlist: wildcard matches any value for tool"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_WINDOW_SIZE=20
export HB_LOOP_THRESHOLD=3
export HB_ERROR_THRESHOLD=5
export HB_CONTEXT_PCT=80
export HB_CONTEXT_WINDOW_BYTES=4000000
export HB_MAX_NUDGES=3
export HB_DRY_RUN=0
export HB_ALLOWLIST="Bash:*"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/state.sh"
source "$LIB_DIR/detect.sh"

init_state "test-allow-003"
append_tool_call "Bash" "npm test" 100
append_tool_call "Bash" "npm test" 100
append_tool_call "Bash" "npm test" 100
result="$(detect_loop)"
assert_contains "$result" "none" "wildcard allowlist skips all Bash fingerprints"
teardown_test_env

run_test "allowlist: empty allowlist does not suppress detection"
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

init_state "test-allow-004"
append_tool_call "Bash" "npm test" 100
append_tool_call "Bash" "npm test" 100
append_tool_call "Bash" "npm test" 100
result="$(detect_loop)"
assert_contains "$result" "permission-hammer" "empty allowlist does not suppress"
teardown_test_env

# ── Feature 4: Session Tombstones ────────────────────────────────────────────

run_test "write_tombstone creates file in tombstones dir"
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

init_state "test-tomb-001"
write_tombstone "edit-undo-cycle" "You looped too much."
ts_files=("$HB_STATE_DIR/tombstones/"*.json)
assert_file_exists "${ts_files[0]}" "tombstone file created"
teardown_test_env

run_test "write_tombstone records pattern and message"
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

init_state "test-tomb-002"
write_tombstone "grep-spiral" "Too many searches."
ts_file="$(ls -t "$HB_STATE_DIR/tombstones/"*.json | head -1)"
assert_json_field "$ts_file" ".pattern" "grep-spiral" "tombstone pattern"
assert_json_field "$ts_file" ".message" "Too many searches." "tombstone message"
teardown_test_env

run_test "read_latest_tombstone returns most recent tombstone"
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

init_state "test-tomb-003"
write_tombstone "edit-undo-cycle" "First tombstone."
sleep 1
write_tombstone "grep-spiral" "Second tombstone."
content="$(read_latest_tombstone)"
assert_contains "$content" "grep-spiral" "read_latest_tombstone returns most recent"
teardown_test_env

run_test "tombstone displayed on session-start"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_STALL_TIMEOUT=9999
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

# Pre-seed a tombstone
init_state "previous-session"
write_tombstone "permission-hammer" "Retried same command too many times."

# Now start a new session — tombstone should be shown
output="$(echo '{"session_id":"new-session","source":"startup"}' | bash "$SCRIPT_DIR/../scripts/session-start.sh" 2>&1)"
assert_contains "$output" "Previous session died" "session-start shows tombstone warning"
assert_contains "$output" "permission-hammer" "tombstone pattern shown"

# Kill stall timer
pid="$(jq -r '.stall_timer_pid // empty' "$HB_STATE_DIR/state.json" 2>/dev/null || true)"
[[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
teardown_test_env

run_test "pre-tool-use writes tombstone when max_nudges exceeded"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_WINDOW_SIZE=20
export HB_LOOP_THRESHOLD=3
export HB_ERROR_THRESHOLD=5
export HB_CONTEXT_PCT=80
export HB_CONTEXT_WINDOW_BYTES=4000000
export HB_MAX_NUDGES=2
export HB_DRY_RUN=0
export HB_ALLOWLIST=""
source "$LIB_DIR/config.sh"
source "$LIB_DIR/state.sh"

HOOK="$SCRIPT_DIR/../scripts/pre-tool-use.sh"
init_state "test-tomb-pre"
# Set intervention_count to HB_MAX_NUDGES so this next block triggers max_nudges path
jq '.intervention_count = 2' "$HB_STATE_DIR/state.json" > "$HB_STATE_DIR/state.json.tmp" \
  && mv "$HB_STATE_DIR/state.json.tmp" "$HB_STATE_DIR/state.json"
set_intervention "edit-undo-cycle" "You looped too much."
echo '{}' | bash "$HOOK" 2>/dev/null || true
tombstone_count="$(ls "$HB_STATE_DIR/tombstones/"*.json 2>/dev/null | wc -l | tr -d ' ')"
assert_contains "$tombstone_count" "1" "tombstone written after max_nudges exceeded"
teardown_test_env

# ── Feature 5: Team Config (.heartbeat.yml) ──────────────────────────────────

run_test "team config overrides defaults"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"

TEAM_CONFIG="$HEARTBEAT_DIR/.heartbeat.yml"
cat > "$TEAM_CONFIG" <<'EOF'
loop_threshold: 7
error_threshold: 10
max_nudges: 5
dry_run: 1
EOF

# Source config with the team config file in place
export HB_CONFIG_FILE="$TEAM_CONFIG"
# Unset existing HB_ vars so config.sh picks up team values (not env overrides)
unset HB_LOOP_THRESHOLD HB_ERROR_THRESHOLD HB_MAX_NUDGES HB_DRY_RUN 2>/dev/null || true
unset HEARTBEAT_LOOP_THRESHOLD HEARTBEAT_ERROR_THRESHOLD HEARTBEAT_MAX_NUDGES HEARTBEAT_DRY_RUN 2>/dev/null || true
source "$LIB_DIR/config.sh"

assert_contains "$HB_LOOP_THRESHOLD" "7" "team config sets loop_threshold"
assert_contains "$HB_ERROR_THRESHOLD" "10" "team config sets error_threshold"
assert_contains "$HB_MAX_NUDGES" "5" "team config sets max_nudges"
assert_contains "$HB_DRY_RUN" "1" "team config sets dry_run"
teardown_test_env

run_test "team config ignored when file absent"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"

# Point at non-existent config file
export HB_CONFIG_FILE="$HEARTBEAT_DIR/nonexistent.yml"
unset HB_LOOP_THRESHOLD 2>/dev/null || true
unset HEARTBEAT_LOOP_THRESHOLD 2>/dev/null || true
source "$LIB_DIR/config.sh"

assert_contains "$HB_LOOP_THRESHOLD" "3" "default used when no team config"
teardown_test_env

run_test "team config skips comments and blank lines"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"

TEAM_CONFIG="$HEARTBEAT_DIR/.heartbeat.yml"
cat > "$TEAM_CONFIG" <<'EOF'
# This is a comment
loop_threshold: 4

# Another comment
max_nudges: 6
EOF

export HB_CONFIG_FILE="$TEAM_CONFIG"
unset HB_LOOP_THRESHOLD HB_MAX_NUDGES 2>/dev/null || true
unset HEARTBEAT_LOOP_THRESHOLD HEARTBEAT_MAX_NUDGES 2>/dev/null || true
source "$LIB_DIR/config.sh"

assert_contains "$HB_LOOP_THRESHOLD" "4" "comments skipped correctly"
assert_contains "$HB_MAX_NUDGES" "6" "blank lines skipped correctly"
teardown_test_env

run_test "env vars override team config"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"

TEAM_CONFIG="$HEARTBEAT_DIR/.heartbeat.yml"
cat > "$TEAM_CONFIG" <<'EOF'
loop_threshold: 9
EOF

export HB_CONFIG_FILE="$TEAM_CONFIG"
# env var set before sourcing (simulates user env override)
export HEARTBEAT_LOOP_THRESHOLD=2
source "$LIB_DIR/config.sh"

assert_contains "$HB_LOOP_THRESHOLD" "2" "env var overrides team config"
unset HEARTBEAT_LOOP_THRESHOLD
teardown_test_env

print_summary
