#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "  PostToolUse hook tests"

HOOK="$SCRIPT_DIR/../scripts/post-tool-use.sh"
setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_WINDOW_SIZE=20
export HB_LOOP_THRESHOLD=3
export HB_ERROR_THRESHOLD=5
export HB_CONTEXT_PCT=80
export HB_CONTEXT_WINDOW_BYTES=4000000
export HB_MAX_NUDGES=3

LIB_DIR="$SCRIPT_DIR/../scripts/lib"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/state.sh"
init_state "test-post-001"

run_test "processes edit event and updates state"
cat "$SCRIPT_DIR/fixtures/post_tool_use_edit.json" | bash "$HOOK"
exit_code=$?
assert_exit 0 "$exit_code" "exit 0 on normal event"
assert_json_field "$HB_STATE_DIR/state.json" ".tool_calls | length" "1" "1 call tracked"
assert_json_field "$HB_STATE_DIR/state.json" ".consecutive_errors" "0" "no errors"

run_test "resets error counter on success"
increment_errors
increment_errors
cat "$SCRIPT_DIR/fixtures/post_tool_use_edit.json" | bash "$HOOK"
assert_json_field "$HB_STATE_DIR/state.json" ".consecutive_errors" "0" "errors reset on success"

run_test "sets intervention flag after loop"
init_state "test-post-002"
cat "$SCRIPT_DIR/fixtures/post_tool_use_edit.json" | bash "$HOOK"
cat "$SCRIPT_DIR/fixtures/post_tool_use_edit.json" | bash "$HOOK"
cat "$SCRIPT_DIR/fixtures/post_tool_use_edit.json" | bash "$HOOK"
pattern="$(jq -r '.intervention.pattern // "null"' "$HB_STATE_DIR/state.json")"
assert_contains "$pattern" "edit-undo-cycle" "intervention set"

teardown_test_env
print_summary
