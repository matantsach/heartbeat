#!/usr/bin/env bash
# lib/detect.sh — pattern matching functions for pathological behavior

is_allowlisted() {
  local fingerprint="$1"
  [[ -z "$HB_ALLOWLIST" ]] && return 1

  local IFS=','
  for pattern in $HB_ALLOWLIST; do
    pattern="$(echo "$pattern" | tr -d ' ')"
    # Support wildcards: "Bash:*" matches any Bash command
    # shellcheck disable=SC2053
    if [[ "$fingerprint" == $pattern ]]; then
      return 0
    fi
  done
  return 1
}

detect_loop() {
  local state_file="$HB_STATE_DIR/state.json"
  local threshold="$HB_LOOP_THRESHOLD"

  # Get all fingerprints at the maximum count, sorted by first-occurrence index
  local candidates
  candidates="$(jq -r --argjson threshold "$threshold" '
    [.tool_calls[] | .fingerprint] as $fps |
    ($fps | group_by(.) | map({fp: .[0], count: length}) | map(select(.count >= $threshold))) as $over |
    if ($over | length) == 0 then empty
    else
      # For each candidate, find the index of first occurrence
      ($over | map(.fp) ) as $cand_fps |
      $over | map(
        . as $entry |
        ($fps | indices($entry.fp)[0]) as $first_idx |
        {fp: $entry.fp, count: $entry.count, first: $first_idx}
      ) | sort_by(.first) | .[0]
    end
  ' "$state_file")"

  if [[ -z "$candidates" ]]; then
    echo "none"
    return
  fi

  local fp_value
  fp_value="$(echo "$candidates" | jq -r '.fp')"

  # Skip allowlisted fingerprints
  if is_allowlisted "$fp_value"; then
    echo "none"
    return
  fi

  local tool_name
  tool_name="$(echo "$fp_value" | cut -d: -f1)"
  case "$tool_name" in
    Edit|Write)  echo "edit-undo-cycle" ;;
    Grep|Search) echo "grep-spiral" ;;
    Bash)        echo "permission-hammer" ;;
    *)           echo "loop-detected" ;;
  esac
}

detect_error_spiral() {
  local state_file="$HB_STATE_DIR/state.json"
  local errors
  errors="$(jq -r '.consecutive_errors' "$state_file")"

  if [[ "$errors" -ge "$HB_ERROR_THRESHOLD" ]]; then
    echo "error-cascade"
  else
    echo "none"
  fi
}

detect_context_pressure() {
  local state_file="$HB_STATE_DIR/state.json"
  local total_bytes
  total_bytes="$(jq -r '.total_output_bytes' "$state_file")"
  local threshold_bytes
  threshold_bytes=$(( HB_CONTEXT_WINDOW_BYTES * HB_CONTEXT_PCT / 100 ))

  if [[ "$total_bytes" -ge "$threshold_bytes" ]]; then
    echo "context-cliff"
  else
    echo "none"
  fi
}

get_nudge_message() {
  local pattern="$1"
  local state_file="$HB_STATE_DIR/state.json"
  local target
  target="$(jq -r '.tool_calls[-1].target // "unknown"' "$state_file")"

  # Try loading from pattern file first
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local patterns_dir="$script_dir/../../patterns"

  if [[ -f "$patterns_dir/${pattern}.json" ]]; then
    local template
    template="$(jq -r '.nudge' "$patterns_dir/${pattern}.json")"
    # Replace placeholders
    template="${template//\{target\}/$target}"
    template="${template//\{threshold\}/$HB_LOOP_THRESHOLD}"
    template="${template//\{context_pct\}/$HB_CONTEXT_PCT}"
    echo "Heartbeat: $(jq -r '.display_name' "$patterns_dir/${pattern}.json") detected. $template"
    return
  fi

  # Check user custom patterns
  if [[ -d "$HB_STATE_DIR/patterns" && -f "$HB_STATE_DIR/patterns/${pattern}.json" ]]; then
    local template
    template="$(jq -r '.nudge' "$HB_STATE_DIR/patterns/${pattern}.json")"
    template="${template//\{target\}/$target}"
    template="${template//\{threshold\}/$HB_LOOP_THRESHOLD}"
    template="${template//\{context_pct\}/$HB_CONTEXT_PCT}"
    echo "Heartbeat: $(jq -r '.display_name' "$HB_STATE_DIR/patterns/${pattern}.json") detected. $template"
    return
  fi

  # Fallback to hardcoded (keep existing logic for backwards compat)
  case "$pattern" in
    edit-undo-cycle)
      echo "Heartbeat: Edit-Undo Cycle detected. You've edited '$target' $HB_LOOP_THRESHOLD+ times with similar changes. Step back and try a fundamentally different approach." ;;
    grep-spiral)
      echo "Heartbeat: Grep Spiral detected. You've searched for similar patterns $HB_LOOP_THRESHOLD+ times. The file or pattern you're looking for may not exist. Try listing directory contents or reading the file directly." ;;
    permission-hammer)
      echo "Heartbeat: Permission Hammer detected. You've retried the same failing command $HB_LOOP_THRESHOLD+ times. The root cause may be a missing dependency, wrong path, or permission issue. Diagnose before retrying." ;;
    error-cascade)
      echo "Heartbeat: Error Cascade detected. $HB_ERROR_THRESHOLD consecutive tool calls have failed. Stop and diagnose the root cause before continuing." ;;
    context-cliff)
      echo "Heartbeat: Context Pressure warning. Estimated context usage has exceeded ${HB_CONTEXT_PCT}%. Consider running /compact to free context space before continuing." ;;
    loop-detected)
      echo "Heartbeat: Loop detected. You've repeated the same action on '$target' $HB_LOOP_THRESHOLD+ times. Try a different approach." ;;
    *)
      echo "Heartbeat: Pathological pattern detected ($pattern). Consider changing your approach." ;;
  esac
}
