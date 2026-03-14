#!/usr/bin/env bash
# post-tool-use.sh — PostToolUse hook: update state, run detection, set flags
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/notify.sh"

INPUT="$(cat)"

# Change to project directory (Copilot CLI runs hooks from plugin install dir)
INPUT_CWD="$(echo "$INPUT" | jq -r '.cwd // empty')"
if [[ -n "$INPUT_CWD" && -d "$INPUT_CWD" ]]; then
  cd "$INPUT_CWD"
fi

# Support both Claude Code (snake_case) and Copilot CLI (camelCase) field names
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // .toolName // "unknown"')"
TOOL_INPUT="$(echo "$INPUT" | jq -r '.tool_input // .toolArgs // {}')"
TOOL_OUTPUT="$(echo "$INPUT" | jq -r '.tool_output // .toolResult // ""')"

TARGET="$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // .command // .pattern // "unknown"' 2>/dev/null || echo "unknown")"
OUTPUT_BYTES="$(echo -n "$TOOL_OUTPUT" | wc -c | tr -d ' ')"

# Compute content hash for smarter fingerprinting
CONTENT_HASH=""
case "$TOOL_NAME" in
  Edit)
    # Hash file_path + old_string — same region = same intent
    hash_input="$(echo "$TOOL_INPUT" | jq -r '(.file_path // "") + (.old_string // "")' 2>/dev/null || true)"
    if [[ -n "$hash_input" ]]; then
      CONTENT_HASH="$(printf '%s' "$hash_input" | cksum | cut -d' ' -f1)"
    fi
    ;;
esac

if [[ ! -f "$HB_STATE_DIR/state.json" ]]; then
  exit 0
fi

reset_errors
append_tool_call "$TOOL_NAME" "$TARGET" "$OUTPUT_BYTES" "$CONTENT_HASH"
touch "$HB_STATE_DIR/.last_activity"
rm -f "$HB_STATE_DIR/.stall_notified"

LOOP_RESULT="$(detect_loop)"
if [[ "$LOOP_RESULT" != "none" ]]; then
  NUDGE_MSG="$(get_nudge_message "$LOOP_RESULT")"
  set_intervention "$LOOP_RESULT" "$NUDGE_MSG"
  log_incident "$LOOP_RESULT" "flag_set" "$NUDGE_MSG"
  exit 0
fi

CTX_RESULT="$(detect_context_pressure)"
if [[ "$CTX_RESULT" != "none" ]]; then
  NUDGE_MSG="$(get_nudge_message "$CTX_RESULT")"
  set_intervention "$CTX_RESULT" "$NUDGE_MSG"
  log_incident "$CTX_RESULT" "flag_set" "$NUDGE_MSG"
  exit 0
fi

exit 0
