#!/usr/bin/env bash
# test/helpers.sh — shared test utilities
set -euo pipefail

TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""

setup_test_env() {
  export HEARTBEAT_DIR
  HEARTBEAT_DIR="$(mktemp -d)"
  export HEARTBEAT_STATE_DIR="$HEARTBEAT_DIR"
  export HEARTBEAT_TEST_MODE=1
}

teardown_test_env() {
  rm -rf "$HEARTBEAT_DIR"
}

assert_exit() {
  local expected="$1" actual="$2" label="${3:-}"
  if [[ "$actual" -eq "$expected" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: ${label:-exit code} — expected $expected, got $actual"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="${3:-}"
  if echo "$haystack" | grep -q "$needle"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: ${label:-output} — expected to contain '$needle'"
    echo "  Got: $haystack"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="${3:-}"
  if echo "$haystack" | grep -q "$needle"; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: ${label:-output} — expected NOT to contain '$needle'"
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}

assert_file_exists() {
  local path="$1" label="${2:-}"
  if [[ -f "$path" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: ${label:-file} — expected $path to exist"
  fi
}

assert_json_field() {
  local file="$1" field="$2" expected="$3" label="${4:-}"
  local actual
  actual="$(jq -r "$field" "$file" 2>/dev/null || echo "__JQ_ERROR__")"
  if [[ "$actual" == "$expected" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: ${label:-json field} — $field expected '$expected', got '$actual'"
  fi
}

run_test() {
  CURRENT_TEST="$1"
  echo "  - $CURRENT_TEST"
}

print_summary() {
  local total=$((TESTS_PASSED + TESTS_FAILED))
  echo ""
  if [[ "$TESTS_FAILED" -eq 0 ]]; then
    echo "OK: $total tests passed"
  else
    echo "FAIL: $TESTS_FAILED/$total tests failed"
  fi
  return "$TESTS_FAILED"
}
