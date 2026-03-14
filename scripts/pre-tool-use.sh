#!/usr/bin/env bash
# pre-tool-use.sh — PreToolUse hook: check for intervention flags, block if set
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/notify.sh"
source "$SCRIPT_DIR/lib/log.sh"

INPUT="$(cat)"

# Change to project directory (Copilot CLI runs hooks from plugin install dir)
INPUT_CWD="$(echo "$INPUT" | jq -r '.cwd // empty')"
if [[ -n "$INPUT_CWD" && -d "$INPUT_CWD" ]]; then
  cd "$INPUT_CWD"
fi

if [[ ! -f "$HB_STATE_DIR/state.json" ]]; then
  exit 0
fi

INTERVENTION="$(jq -r '.intervention // empty' "$HB_STATE_DIR/state.json")"
if [[ -z "$INTERVENTION" || "$INTERVENTION" == "null" ]]; then
  exit 0
fi

PATTERN="$(echo "$INTERVENTION" | jq -r '.pattern')"
MESSAGE="$(echo "$INTERVENTION" | jq -r '.message')"
CURRENT_COUNT="$(get_state_field '.intervention_count')"

clear_intervention
increment_intervention_count

# Dry-run mode: log but don't block
if [[ "$HB_DRY_RUN" == "1" ]]; then
  log_incident "$PATTERN" "dry_run_detected" "$MESSAGE"
  exit 0
fi

if [[ "$CURRENT_COUNT" -ge "$HB_MAX_NUDGES" ]]; then
  send_notification "Heartbeat: Agent Stuck" "$PATTERN detected $((CURRENT_COUNT + 1)) times. Manual intervention may be needed."
  send_webhook "escalation" "$PATTERN" "Max nudges exceeded"
  log_incident "$PATTERN" "notification_sent" "Max nudges ($HB_MAX_NUDGES) exceeded"
  write_tombstone "$PATTERN" "$MESSAGE"
fi

log_incident "$PATTERN" "tool_blocked" "$MESSAGE"
send_webhook "intervention" "$PATTERN" "$MESSAGE"

if [[ "$HB_CI_MODE" == "1" || "$HB_CI_MODE" == "true" ]]; then
  jq -n -c \
    --arg pat "$PATTERN" \
    --arg msg "$MESSAGE" \
    --argjson count "$((CURRENT_COUNT + 1))" \
    '{status: "blocked", pattern: $pat, message: $msg, intervention_count: $count}' \
    > "$HB_STATE_DIR/result.json"
fi

echo "$MESSAGE" >&2
exit 2
