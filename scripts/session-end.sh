#!/usr/bin/env bash
# session-end.sh — print summary, kill stall timer, cleanup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/state.sh"

cat > /dev/null

if [[ ! -f "$HB_STATE_DIR/state.json" ]]; then
  exit 0
fi

# Kill stall timer via PID file
if [[ -f "$HB_STATE_DIR/.timer_pid" ]]; then
  TIMER_PID="$(cat "$HB_STATE_DIR/.timer_pid" 2>/dev/null || true)"
  if [[ -n "$TIMER_PID" ]]; then
    kill "$TIMER_PID" 2>/dev/null || true
  fi
  rm -f "$HB_STATE_DIR/.timer_pid"
fi
# Remove sentinel — timer loop will exit on next iteration if kill missed
rm -f "$HB_STATE_DIR/.alive"
rm -f "$HB_STATE_DIR/.stall_notified"

TOTAL_CALLS="$(get_state_field '.total_tool_calls')"
INTERVENTIONS="$(get_state_field '.intervention_count')"
START_TIME="$(get_state_field '.start_time')"

if [[ -n "$START_TIME" && "$START_TIME" != "null" ]]; then
  START_EPOCH="$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$START_TIME" +%s 2>/dev/null || date -d "$START_TIME" +%s 2>/dev/null || echo 0)"
  NOW_EPOCH="$(date +%s)"
  DURATION_S=$((NOW_EPOCH - START_EPOCH))
  if [[ "$DURATION_S" -ge 60 ]]; then
    DURATION="$((DURATION_S / 60))m"
  else
    DURATION="${DURATION_S}s"
  fi
else
  DURATION="unknown"
fi

DRY_RUN_SUFFIX=""
if [[ "$HB_DRY_RUN" == "1" ]]; then
  DRY_RUN_SUFFIX=" (dry-run)"
fi

if [[ "$INTERVENTIONS" -eq 0 ]]; then
  echo "Heartbeat: $TOTAL_CALLS tool calls, $DURATION, no issues${DRY_RUN_SUFFIX}" >&2
else
  echo "Heartbeat: $TOTAL_CALLS tool calls, $DURATION, $INTERVENTIONS interventions${DRY_RUN_SUFFIX}" >&2
fi

if [[ "$HB_CI_MODE" == "1" || "$HB_CI_MODE" == "true" ]]; then
  jq -n -c \
    --argjson calls "$TOTAL_CALLS" \
    --argjson interventions "$INTERVENTIONS" \
    --arg duration "$DURATION" \
    --arg status "$([ "$INTERVENTIONS" -gt 0 ] && echo "interventions_occurred" || echo "clean")" \
    '{status: $status, total_tool_calls: $calls, interventions: $interventions, duration: $duration}' \
    > "$HB_STATE_DIR/result.json"
fi

exit 0
