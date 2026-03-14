#!/usr/bin/env bash
# post-tool-use-failure.sh — increment error counter, check for spiral
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/notify.sh"

cat > /dev/null

if [[ ! -f "$HB_STATE_DIR/state.json" ]]; then
  exit 0
fi

increment_errors
touch "$HB_STATE_DIR/.last_activity"

ERROR_RESULT="$(detect_error_spiral)"
if [[ "$ERROR_RESULT" != "none" ]]; then
  NUDGE_MSG="$(get_nudge_message "$ERROR_RESULT")"
  set_intervention "$ERROR_RESULT" "$NUDGE_MSG"
  log_incident "$ERROR_RESULT" "flag_set" "$NUDGE_MSG"
fi

exit 0
