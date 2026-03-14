#!/usr/bin/env bash
# test/run-tests.sh — run all test files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0

echo "Heartbeat Test Suite"
echo "===================="

for test_file in "$SCRIPT_DIR"/test_*.sh; do
  [[ -f "$test_file" ]] || continue
  test_name="$(basename "$test_file" .sh)"
  echo ""
  echo "[$test_name]"

  if bash "$test_file"; then
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
done

echo ""
echo "===================="
echo "Suites: $((TOTAL_PASS + TOTAL_FAIL)) total, $TOTAL_PASS passed, $TOTAL_FAIL failed"

exit "$TOTAL_FAIL"
