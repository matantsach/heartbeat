#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
LIB_DIR="$SCRIPT_DIR/../scripts/lib"

echo "  Loop detection tests"

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
source "$LIB_DIR/detect.sh"

run_test "no loop detected with different tool calls"
init_state "test-001"
append_tool_call "Edit" "src/auth.ts" 100
append_tool_call "Bash" "npm test" 200
append_tool_call "Read" "src/utils.ts" 150
result="$(detect_loop)"
assert_contains "$result" "none" "no loop"

run_test "loop detected after 3 identical fingerprints"
init_state "test-002"
append_tool_call "Edit" "src/auth.ts" 100
append_tool_call "Edit" "src/auth.ts" 100
append_tool_call "Edit" "src/auth.ts" 100
result="$(detect_loop)"
assert_contains "$result" "edit-undo-cycle" "loop detected"

run_test "no loop with 2 identical (below threshold)"
init_state "test-003"
append_tool_call "Edit" "src/auth.ts" 100
append_tool_call "Edit" "src/auth.ts" 100
result="$(detect_loop)"
assert_contains "$result" "none" "below threshold"

run_test "grep spiral detected"
init_state "test-004"
append_tool_call "Grep" "pattern1" 100
append_tool_call "Grep" "pattern1" 100
append_tool_call "Grep" "pattern1" 100
result="$(detect_loop)"
assert_contains "$result" "grep-spiral" "grep spiral detected"

run_test "interleaved loop detected (edit-test-edit-test-edit-test)"
init_state "test-005"
append_tool_call "Edit" "src/auth.ts" 100
append_tool_call "Bash" "npm test" 200
append_tool_call "Edit" "src/auth.ts" 100
append_tool_call "Bash" "npm test" 200
append_tool_call "Edit" "src/auth.ts" 100
append_tool_call "Bash" "npm test" 200
result="$(detect_loop)"
assert_contains "$result" "edit-undo-cycle" "interleaved loop"

teardown_test_env
print_summary
