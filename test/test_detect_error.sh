#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
LIB_DIR="$SCRIPT_DIR/../scripts/lib"

echo "  Error spiral detection tests"

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

run_test "no error spiral below threshold"
init_state "test-err-001"
increment_errors
increment_errors
increment_errors
result="$(detect_error_spiral)"
assert_contains "$result" "none" "below threshold"

run_test "error spiral at threshold"
increment_errors
increment_errors
result="$(detect_error_spiral)"
assert_contains "$result" "error-cascade" "at threshold"

run_test "reset clears spiral"
reset_errors
result="$(detect_error_spiral)"
assert_contains "$result" "none" "after reset"

teardown_test_env
print_summary
