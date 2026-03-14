#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "  PreToolUse intervention tests"

HOOK="$SCRIPT_DIR/../scripts/pre-tool-use.sh"
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

run_test "allows tool call when no intervention flag"
init_state "test-pre-001"
output="$(cat "$SCRIPT_DIR/fixtures/pre_tool_use_edit.json" | bash "$HOOK" 2>&1)" && exit_code=$? || exit_code=$?
assert_exit 0 "$exit_code" "exit 0 = allow"

run_test "blocks tool call when intervention flag set"
set_intervention "edit-undo-cycle" "You've edited src/auth.ts 3 times. Try a different approach."
output="$(cat "$SCRIPT_DIR/fixtures/pre_tool_use_edit.json" | bash "$HOOK" 2>&1)" && exit_code=$? || exit_code=$?
assert_exit 2 "$exit_code" "exit 2 = block"
assert_contains "$output" "edit" "includes pattern context"
assert_contains "$output" "different approach" "includes guidance"

run_test "clears intervention flag after blocking"
flag="$(jq -r '.intervention' "$HB_STATE_DIR/state.json")"
assert_contains "$flag" "null" "flag cleared after block"

run_test "increments intervention count"
assert_json_field "$HB_STATE_DIR/state.json" ".intervention_count" "1" "count incremented"

teardown_test_env
print_summary
