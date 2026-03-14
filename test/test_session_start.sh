#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "  SessionStart hook tests"

HOOK="$SCRIPT_DIR/../scripts/session-start.sh"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_STALL_TIMEOUT=9999

run_test "initializes state on startup"
echo '{"session_id":"test-ss-001","hook_event_name":"SessionStart","source":"startup","cwd":"/tmp/test"}' | bash "$HOOK" 2>/dev/null
assert_file_exists "$HB_STATE_DIR/state.json" "state file created"
assert_json_field "$HB_STATE_DIR/state.json" ".session_id" "test-ss-001" "session id set"
# Kill stall timer
[[ -f "$HB_STATE_DIR/.timer_pid" ]] && kill "$(cat "$HB_STATE_DIR/.timer_pid")" 2>/dev/null || true

run_test "first-run shows demo message"
rm -rf "$HB_STATE_DIR"
output="$(echo '{"session_id":"test-ss-002","hook_event_name":"SessionStart","source":"startup","cwd":"/tmp/test"}' | bash "$HOOK" 2>&1)"
assert_contains "$output" "Heartbeat" "shows heartbeat name"
assert_contains "$output" "installed" "shows install message"
# Kill stall timer
[[ -f "$HB_STATE_DIR/.timer_pid" ]] && kill "$(cat "$HB_STATE_DIR/.timer_pid")" 2>/dev/null || true

run_test "re-initializes on compact source"
echo '{"session_id":"test-ss-003","hook_event_name":"SessionStart","source":"compact","cwd":"/tmp/test"}' | bash "$HOOK" 2>/dev/null
assert_file_exists "$HB_STATE_DIR/state.json" "state still exists after compact"

run_test "stall timer creates sentinel and PID file"
rm -rf "$HB_STATE_DIR"
echo '{"session_id":"test-ss-sentinel","source":"startup"}' | bash "$HOOK" 2>/dev/null
assert_file_exists "$HB_STATE_DIR/.alive" "sentinel file created"
assert_file_exists "$HB_STATE_DIR/.timer_pid" "timer PID file created"
# Cleanup
[[ -f "$HB_STATE_DIR/.timer_pid" ]] && kill "$(cat "$HB_STATE_DIR/.timer_pid")" 2>/dev/null || true

teardown_test_env
print_summary
