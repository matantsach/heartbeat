#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
LIB_DIR="$SCRIPT_DIR/../scripts/lib"

echo "  Config module tests"

run_test "defaults are set when no env vars"
unset HEARTBEAT_LOOP_THRESHOLD HEARTBEAT_STALL_TIMEOUT HEARTBEAT_ERROR_THRESHOLD HEARTBEAT_CONTEXT_PCT 2>/dev/null || true
source "$LIB_DIR/config.sh"
assert_exit 0 $? "source config"
assert_contains "$HB_LOOP_THRESHOLD" "3" "default loop threshold"
assert_contains "$HB_STALL_TIMEOUT" "120" "default stall timeout"
assert_contains "$HB_ERROR_THRESHOLD" "5" "default error threshold"
assert_contains "$HB_CONTEXT_PCT" "80" "default context pct"
assert_contains "$HB_MAX_NUDGES" "3" "default max nudges"

run_test "env vars override defaults"
export HEARTBEAT_LOOP_THRESHOLD=5
export HEARTBEAT_STALL_TIMEOUT=60
source "$LIB_DIR/config.sh"
assert_contains "$HB_LOOP_THRESHOLD" "5" "overridden loop threshold"
assert_contains "$HB_STALL_TIMEOUT" "60" "overridden stall timeout"
unset HEARTBEAT_LOOP_THRESHOLD HEARTBEAT_STALL_TIMEOUT

print_summary
