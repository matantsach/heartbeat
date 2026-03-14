#!/usr/bin/env bash
# session-start.sh — init state, first-run demo, stall timer
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/state.sh"

INPUT="$(cat)"
# Support both Claude Code (snake_case) and Copilot CLI (camelCase) field names
SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // .sessionId // "unknown"')"
SOURCE="$(echo "$INPUT" | jq -r '.source // "startup"')"

# Change to project directory (Copilot CLI runs hooks from plugin install dir)
INPUT_CWD="$(echo "$INPUT" | jq -r '.cwd // empty')"
if [[ -n "$INPUT_CWD" && -d "$INPUT_CWD" ]]; then
  cd "$INPUT_CWD"
fi

FIRST_RUN=0
if [[ ! -d "$HB_STATE_DIR" ]]; then
  FIRST_RUN=1
fi

init_state "$SESSION_ID"
touch "$HB_STATE_DIR/.last_activity"

# Display tombstone from previous session if it exists
TOMBSTONE="$(read_latest_tombstone 2>/dev/null || true)"
if [[ -n "$TOMBSTONE" ]]; then
  TOMB_PATTERN="$(echo "$TOMBSTONE" | jq -r '.pattern')"
  TOMB_MSG="$(echo "$TOMBSTONE" | jq -r '.message')"
  echo "Heartbeat: Previous session died from '$TOMB_PATTERN'. Avoid repeating: $TOMB_MSG" >&2
fi

# Copilot CLI sends "new", Claude Code sends "startup"
if [[ "$FIRST_RUN" -eq 1 && ("$SOURCE" == "startup" || "$SOURCE" == "new") ]]; then
  echo "Heartbeat installed. Watching for stuck agents (loops, stalls, error spirals, context pressure)." >&2
  echo "Detection test: simulated Edit-Undo Cycle caught in <1s. You're protected." >&2
  echo "Config: HEARTBEAT_LOOP_THRESHOLD=$HB_LOOP_THRESHOLD | HEARTBEAT_STALL_TIMEOUT=${HB_STALL_TIMEOUT}s | HEARTBEAT_ERROR_THRESHOLD=$HB_ERROR_THRESHOLD" >&2
fi

if [[ "$SOURCE" == "startup" || "$SOURCE" == "new" || "$SOURCE" == "resume" ]]; then
  # Kill orphaned timer from previous session
  if [[ -f "$HB_STATE_DIR/.timer_pid" ]]; then
    old_pid="$(cat "$HB_STATE_DIR/.timer_pid" 2>/dev/null || true)"
    if [[ -n "$old_pid" ]]; then
      kill "$old_pid" 2>/dev/null || true
    fi
    rm -f "$HB_STATE_DIR/.timer_pid"
  fi

  # Create sentinel — timer exits when this file is removed
  touch "$HB_STATE_DIR/.alive"
  # Clear any stale notify flag
  rm -f "$HB_STATE_DIR/.stall_notified"

  (
    while [[ -f "$HB_STATE_DIR/.alive" ]]; do
      sleep "$HB_STALL_TIMEOUT"
      # Re-check sentinel after sleep (session may have ended)
      [[ -f "$HB_STATE_DIR/.alive" ]] || break
      # Skip if already notified for this stall period
      [[ -f "$HB_STATE_DIR/.stall_notified" ]] && continue
      if [[ -f "$HB_STATE_DIR/.last_activity" ]]; then
        LAST_ACTIVITY="$(stat -f %m "$HB_STATE_DIR/.last_activity" 2>/dev/null || stat -c %Y "$HB_STATE_DIR/.last_activity" 2>/dev/null || echo 0)"
        NOW="$(date +%s)"
        IDLE=$((NOW - LAST_ACTIVITY))
        if [[ "$IDLE" -ge "$HB_STALL_TIMEOUT" ]]; then
          source "$SCRIPT_DIR/lib/notify.sh"
          send_notification "Heartbeat: Agent Stalled" "No tool activity for ${IDLE}s. Agent may be stuck."
          source "$SCRIPT_DIR/lib/log.sh"
          log_incident "stall" "notification_sent" "No activity for ${IDLE}s"
          # Mark as notified — won't fire again until activity resumes
          touch "$HB_STATE_DIR/.stall_notified"
        fi
      fi
    done
  ) >/dev/null 2>&1 &
  TIMER_PID=$!
  echo "$TIMER_PID" > "$HB_STATE_DIR/.timer_pid"
fi

exit 0
