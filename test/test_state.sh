#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
LIB_DIR="$SCRIPT_DIR/../scripts/lib"

echo "  State module tests"

setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_WINDOW_SIZE=5
source "$LIB_DIR/config.sh"
source "$LIB_DIR/state.sh"

run_test "init_state creates state file"
init_state "test-session-001"
assert_file_exists "$HB_STATE_DIR/state.json" "state file created"
assert_json_field "$HB_STATE_DIR/state.json" ".session_id" "test-session-001" "session id"
assert_json_field "$HB_STATE_DIR/state.json" ".tool_calls | length" "0" "empty tool calls"
assert_json_field "$HB_STATE_DIR/state.json" ".consecutive_errors" "0" "zero errors"
assert_json_field "$HB_STATE_DIR/state.json" ".total_output_bytes" "0" "zero bytes"
assert_json_field "$HB_STATE_DIR/state.json" ".intervention_count" "0" "zero interventions"

run_test "append_tool_call adds to window"
append_tool_call "Edit" "/tmp/src/auth.ts" 150
append_tool_call "Bash" "npm test" 2000
assert_json_field "$HB_STATE_DIR/state.json" ".tool_calls | length" "2" "two tool calls"
assert_json_field "$HB_STATE_DIR/state.json" ".tool_calls[0].tool" "Edit" "first tool"
assert_json_field "$HB_STATE_DIR/state.json" ".total_output_bytes" "2150" "cumulative bytes"

run_test "window rolls over at max size"
append_tool_call "Read" "file1.ts" 100
append_tool_call "Read" "file2.ts" 100
append_tool_call "Read" "file3.ts" 100
append_tool_call "Read" "file4.ts" 100
len="$(jq -r '.tool_calls | length' "$HB_STATE_DIR/state.json")"
assert_contains "$len" "5" "window capped at 5"

run_test "increment_errors tracks consecutive errors"
increment_errors
increment_errors
increment_errors
assert_json_field "$HB_STATE_DIR/state.json" ".consecutive_errors" "3" "3 errors"

run_test "reset_errors clears counter"
reset_errors
assert_json_field "$HB_STATE_DIR/state.json" ".consecutive_errors" "0" "reset to 0"

run_test "set_intervention_flag writes flag"
set_intervention "edit-undo-cycle" "You've edited src/auth.ts 3 times with similar changes. Try a different approach."
assert_json_field "$HB_STATE_DIR/state.json" ".intervention.pattern" "edit-undo-cycle" "pattern name"

run_test "clear_intervention removes flag"
clear_intervention
assert_json_field "$HB_STATE_DIR/state.json" ".intervention" "null" "intervention cleared"

run_test "increment_intervention_count tracks nudges"
increment_intervention_count
increment_intervention_count
assert_json_field "$HB_STATE_DIR/state.json" ".intervention_count" "2" "2 nudges"

teardown_test_env
print_summary
