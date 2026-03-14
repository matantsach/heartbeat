#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
LIB_DIR="$SCRIPT_DIR/../scripts/lib"

echo "  Context pressure detection tests"

setup_test_env
export HB_STATE_DIR="$HEARTBEAT_DIR"
export HB_WINDOW_SIZE=20
export HB_LOOP_THRESHOLD=3
export HB_ERROR_THRESHOLD=5
export HB_CONTEXT_PCT=80
export HB_CONTEXT_WINDOW_BYTES=10000
export HB_MAX_NUDGES=3
source "$LIB_DIR/config.sh"
source "$LIB_DIR/state.sh"
source "$LIB_DIR/detect.sh"

run_test "no pressure when under threshold"
init_state "test-ctx-001"
append_tool_call "Read" "file.ts" 1000
result="$(detect_context_pressure)"
assert_contains "$result" "none" "under threshold"

run_test "pressure detected at threshold"
append_tool_call "Read" "big-file.ts" 7500
result="$(detect_context_pressure)"
assert_contains "$result" "context-cliff" "at 85% of 10000"

teardown_test_env
print_summary
