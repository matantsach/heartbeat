#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "  v0.3 feature tests"

SCRIPTS="$SCRIPT_DIR/../scripts"
LIB_DIR="$SCRIPTS/lib"

# --- CI/CD Mode Tests ---

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
export HB_STALL_TIMEOUT=9999

run_test "CI mode writes result.json on block"
export HB_CI_MODE=1
source "$LIB_DIR/config.sh"
source "$LIB_DIR/state.sh"
init_state "test-ci-001"
set_intervention "edit-undo-cycle" "Test CI block"
output="$(cat "$SCRIPT_DIR/fixtures/pre_tool_use_edit.json" | bash "$SCRIPTS/pre-tool-use.sh" 2>&1)" && exit_code=$? || exit_code=$?
assert_exit 2 "$exit_code" "still blocks in CI"
assert_file_exists "$HB_STATE_DIR/result.json" "result.json created"
assert_json_field "$HB_STATE_DIR/result.json" ".status" "blocked" "status is blocked"
assert_json_field "$HB_STATE_DIR/result.json" ".pattern" "edit-undo-cycle" "pattern recorded"

run_test "CI mode session-end writes final result"
init_state "test-ci-002"
jq '.total_tool_calls = 10 | .intervention_count = 1' "$HB_STATE_DIR/state.json" > "$HB_STATE_DIR/state.json.tmp" \
  && mv "$HB_STATE_DIR/state.json.tmp" "$HB_STATE_DIR/state.json"
echo '{"hook_event_name":"Stop"}' | bash "$SCRIPTS/session-end.sh" 2>/dev/null
assert_file_exists "$HB_STATE_DIR/result.json" "final result.json"
assert_json_field "$HB_STATE_DIR/result.json" ".status" "interventions_occurred" "correct status"
assert_json_field "$HB_STATE_DIR/result.json" ".interventions" "1" "intervention count"

run_test "CI mode clean session writes clean result"
init_state "test-ci-003"
jq '.total_tool_calls = 5' "$HB_STATE_DIR/state.json" > "$HB_STATE_DIR/state.json.tmp" \
  && mv "$HB_STATE_DIR/state.json.tmp" "$HB_STATE_DIR/state.json"
echo '{"hook_event_name":"Stop"}' | bash "$SCRIPTS/session-end.sh" 2>/dev/null
assert_json_field "$HB_STATE_DIR/result.json" ".status" "clean" "clean status"

export HB_CI_MODE=0

# --- Webhook Tests ---

run_test "webhook function exists and handles empty URL gracefully"
export HB_WEBHOOK_URL=""
source "$LIB_DIR/notify.sh"
# Should return 0 (no-op) when URL is empty
send_webhook "test" "test-pattern" "test message"
assert_exit 0 $? "no-op on empty URL"

teardown_test_env
print_summary
