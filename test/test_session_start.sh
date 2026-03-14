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
pid="$(jq -r '.stall_timer_pid // empty' "$HB_STATE_DIR/state.json")"
[[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true

run_test "first-run shows demo message"
rm -rf "$HB_STATE_DIR"
output="$(echo '{"session_id":"test-ss-002","hook_event_name":"SessionStart","source":"startup","cwd":"/tmp/test"}' | bash "$HOOK" 2>&1)"
assert_contains "$output" "Heartbeat" "shows heartbeat name"
assert_contains "$output" "installed" "shows install message"
# Kill stall timer
pid="$(jq -r '.stall_timer_pid // empty' "$HB_STATE_DIR/state.json" 2>/dev/null)"
[[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true

run_test "re-initializes on compact source"
echo '{"session_id":"test-ss-003","hook_event_name":"SessionStart","source":"compact","cwd":"/tmp/test"}' | bash "$HOOK" 2>/dev/null
assert_file_exists "$HB_STATE_DIR/state.json" "state still exists after compact"

teardown_test_env
print_summary
