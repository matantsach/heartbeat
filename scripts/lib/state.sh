#!/usr/bin/env bash
# lib/state.sh — read/write .heartbeat/state.json
# Requires: jq, config.sh sourced first

_state_file() {
  echo "$HB_STATE_DIR/state.json"
}

init_state() {
  local session_id="${1:-unknown}"
  mkdir -p "$HB_STATE_DIR"
  cat > "$(_state_file)" <<EOF
{
  "session_id": "$session_id",
  "start_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tool_calls": [],
  "total_tool_calls": 0,
  "consecutive_errors": 0,
  "total_output_bytes": 0,
  "intervention": null,
  "intervention_count": 0,
  "stall_timer_pid": null
}
EOF
}

append_tool_call() {
  local tool="$1" target="$2" output_bytes="${3:-0}"
  local state_file
  state_file="$(_state_file)"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local fingerprint="${tool}:${target}"

  jq --arg tool "$tool" \
     --arg target "$target" \
     --arg ts "$ts" \
     --arg fp "$fingerprint" \
     --argjson bytes "$output_bytes" \
     --argjson max "$HB_WINDOW_SIZE" \
     '
     .tool_calls += [{"tool": $tool, "target": $target, "ts": $ts, "fingerprint": $fp}] |
     .tool_calls = .tool_calls[-$max:] |
     .total_tool_calls += 1 |
     .total_output_bytes += $bytes
     ' "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
}

increment_errors() {
  local state_file
  state_file="$(_state_file)"
  jq '.consecutive_errors += 1' "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
}

reset_errors() {
  local state_file
  state_file="$(_state_file)"
  jq '.consecutive_errors = 0' "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
}

set_intervention() {
  local pattern="$1" message="$2"
  local state_file
  state_file="$(_state_file)"
  jq --arg pat "$pattern" --arg msg "$message" \
     '.intervention = {"pattern": $pat, "message": $msg}' \
     "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
}

clear_intervention() {
  local state_file
  state_file="$(_state_file)"
  jq '.intervention = null' "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
}

increment_intervention_count() {
  local state_file
  state_file="$(_state_file)"
  jq '.intervention_count += 1' "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
}

get_state_field() {
  local field="$1"
  jq -r "$field" "$(_state_file)"
}

update_stall_timer_pid() {
  local pid="$1"
  local state_file
  state_file="$(_state_file)"
  jq --arg pid "$pid" '.stall_timer_pid = ($pid | tonumber)' \
     "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
}

write_tombstone() {
  local pattern="$1" message="$2"
  local tombstone_dir="$HB_STATE_DIR/tombstones"
  mkdir -p "$tombstone_dir"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local session_id
  session_id="$(get_state_field '.session_id')"

  jq -n -c \
    --arg ts "$ts" \
    --arg sid "$session_id" \
    --arg pat "$pattern" \
    --arg msg "$message" \
    --argjson calls "$(jq '.tool_calls' "$HB_STATE_DIR/state.json")" \
    '{timestamp: $ts, session_id: $sid, pattern: $pat, message: $msg, last_tool_calls: $calls}' \
    > "$tombstone_dir/${ts//:/}-${pattern}.json"
}

read_latest_tombstone() {
  local tombstone_dir="$HB_STATE_DIR/tombstones"
  [[ -d "$tombstone_dir" ]] || return
  local latest
  latest="$(ls -t "$tombstone_dir"/*.json 2>/dev/null | head -1)"
  [[ -n "$latest" ]] && cat "$latest"
}
