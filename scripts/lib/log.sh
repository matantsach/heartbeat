#!/usr/bin/env bash
# lib/log.sh — append incidents to .heartbeat/incidents.jsonl

log_incident() {
  local pattern="$1" action="$2" details="${3:-}"
  local log_file="$HB_STATE_DIR/incidents.jsonl"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local total_calls
  total_calls="$(get_state_field '.total_tool_calls')"

  jq -n -c \
    --arg ts "$ts" \
    --arg pat "$pattern" \
    --arg act "$action" \
    --arg det "$details" \
    --argjson call "$total_calls" \
    '{timestamp: $ts, pattern: $pat, action: $act, details: $det, tool_call_number: $call}' \
    >> "$log_file"
}
