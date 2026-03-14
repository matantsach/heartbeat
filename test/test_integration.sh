#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "  End-to-end integration tests"

SCRIPTS="$SCRIPT_DIR/../scripts"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_STALL_TIMEOUT=9999
export HB_WINDOW_SIZE=20
export HB_LOOP_THRESHOLD=3
export HB_ERROR_THRESHOLD=5
export HB_CONTEXT_PCT=80
export HB_CONTEXT_WINDOW_BYTES=4000000
export HB_MAX_NUDGES=3

run_test "full session lifecycle"

# 1. Session start
echo '{"session_id":"integ-001","hook_event_name":"SessionStart","source":"startup","cwd":"/tmp/test"}' \
  | bash "$SCRIPTS/session-start.sh" 2>/dev/null
assert_file_exists "$HB_STATE_DIR/state.json" "state initialized"

# 2. First edit (no intervention)
echo '{"session_id":"integ-001","tool_name":"Edit","tool_input":{"file_path":"src/auth.ts"},"tool_output":"ok"}' \
  | bash "$SCRIPTS/post-tool-use.sh"
output="$(echo '{"session_id":"integ-001","tool_name":"Edit","tool_input":{"file_path":"src/auth.ts"}}' \
  | bash "$SCRIPTS/pre-tool-use.sh" 2>&1)" && exit_code=$? || exit_code=$?
assert_exit 0 "$exit_code" "first edit allowed"

# 3. Second edit (no intervention yet)
echo '{"session_id":"integ-001","tool_name":"Edit","tool_input":{"file_path":"src/auth.ts"},"tool_output":"ok"}' \
  | bash "$SCRIPTS/post-tool-use.sh"

# 4. Third edit triggers loop detection
echo '{"session_id":"integ-001","tool_name":"Edit","tool_input":{"file_path":"src/auth.ts"},"tool_output":"ok"}' \
  | bash "$SCRIPTS/post-tool-use.sh"

# 5. PreToolUse should now block
output="$(echo '{"session_id":"integ-001","tool_name":"Edit","tool_input":{"file_path":"src/auth.ts"}}' \
  | bash "$SCRIPTS/pre-tool-use.sh" 2>&1)" && exit_code=$? || exit_code=$?
assert_exit 2 "$exit_code" "fourth edit blocked"
assert_contains "$output" "Edit-Undo Cycle" "correct pattern name"

# 6. Next tool call should be allowed (flag was cleared)
output="$(echo '{"session_id":"integ-001","tool_name":"Read","tool_input":{"file_path":"src/utils.ts"}}' \
  | bash "$SCRIPTS/pre-tool-use.sh" 2>&1)" && exit_code=$? || exit_code=$?
assert_exit 0 "$exit_code" "different action allowed"

# 7. Session end
output="$(echo '{"session_id":"integ-001","hook_event_name":"Stop"}' \
  | bash "$SCRIPTS/session-end.sh" 2>&1)"
assert_contains "$output" "Heartbeat:" "summary shown"
assert_contains "$output" "1 intervention" "intervention counted"

# 8. Check incident log
assert_file_exists "$HB_STATE_DIR/incidents.jsonl" "incident log created"

# Kill any background stall timers
TIMER_PID="$(jq -r '.stall_timer_pid // empty' "$HB_STATE_DIR/state.json" 2>/dev/null)"
[[ -n "$TIMER_PID" ]] && kill "$TIMER_PID" 2>/dev/null || true

teardown_test_env
print_summary
