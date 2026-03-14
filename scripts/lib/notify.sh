#!/usr/bin/env bash
# lib/notify.sh — cross-platform desktop notifications and webhook integration

send_notification() {
  local title="$1" message="$2"

  # Skip desktop notifications in CI
  if [[ "${HB_CI_MODE:-0}" == "1" || "${HB_CI_MODE:-0}" == "true" ]]; then
    return 0
  fi

  if [[ "$(uname)" == "Darwin" ]]; then
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
  elif command -v notify-send &>/dev/null; then
    notify-send "$title" "$message" 2>/dev/null || true
  fi
}

send_webhook() {
  local event_type="$1" pattern="$2" message="$3"
  [[ -z "$HB_WEBHOOK_URL" ]] && return 0

  local payload
  payload="$(jq -n -c \
    --arg type "$event_type" \
    --arg pat "$pattern" \
    --arg msg "$message" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg host "$(hostname)" \
    --arg cwd "$(pwd)" \
    '{event: $type, pattern: $pat, message: $msg, timestamp: $ts, host: $host, cwd: $cwd}')"

  # Fire and forget — don't block on webhook failure
  curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$HB_WEBHOOK_URL" \
    >/dev/null 2>&1 &
}
