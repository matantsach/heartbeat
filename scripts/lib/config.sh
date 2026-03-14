#!/usr/bin/env bash
# lib/config.sh — defaults + env var overrides
# Source this file to populate HB_* variables.

# Detection thresholds
HB_LOOP_THRESHOLD="${HEARTBEAT_LOOP_THRESHOLD:-${HB_LOOP_THRESHOLD:-3}}"
HB_STALL_TIMEOUT="${HEARTBEAT_STALL_TIMEOUT:-${HB_STALL_TIMEOUT:-120}}"
HB_ERROR_THRESHOLD="${HEARTBEAT_ERROR_THRESHOLD:-${HB_ERROR_THRESHOLD:-5}}"
HB_CONTEXT_PCT="${HEARTBEAT_CONTEXT_PCT:-${HB_CONTEXT_PCT:-80}}"

# Response settings
HB_MAX_NUDGES="${HEARTBEAT_MAX_NUDGES:-${HB_MAX_NUDGES:-3}}"

# Context window estimate (bytes as proxy — 1M tokens ~ 4MB)
HB_CONTEXT_WINDOW_BYTES="${HEARTBEAT_CONTEXT_WINDOW:-${HB_CONTEXT_WINDOW_BYTES:-4000000}}"

# Rolling window size (number of recent tool calls to track)
HB_WINDOW_SIZE="${HEARTBEAT_WINDOW_SIZE:-${HB_WINDOW_SIZE:-20}}"

# State directory (defaults to .heartbeat in cwd, overridable for testing)
HB_STATE_DIR="${HEARTBEAT_STATE_DIR:-${HB_STATE_DIR:-.heartbeat}}"

# Dry-run mode: detect but don't block
HB_DRY_RUN="${HB_DRY_RUN:-${HEARTBEAT_DRY_RUN:-0}}"

# Allowlist: comma-separated fingerprints to skip (e.g. "Bash:npm test,Grep:*")
HB_ALLOWLIST="${HB_ALLOWLIST:-${HEARTBEAT_ALLOWLIST:-}}"

# CI/CD mode: machine-readable output, no desktop notifications, non-zero exit on block
HB_CI_MODE="${HB_CI_MODE:-${HEARTBEAT_CI:-${CI:-0}}}"

# Webhook URL: POST intervention events when set
HB_WEBHOOK_URL="${HB_WEBHOOK_URL:-${HEARTBEAT_WEBHOOK_URL:-}}"

_load_team_config() {
  local config_file="${HB_CONFIG_FILE:-.heartbeat.yml}"
  [[ -f "$config_file" ]] || return 0

  # Parse YAML-like config (simple key: value format, no full YAML parser needed)
  # Env vars take priority: only apply team config if the corresponding env var is unset.
  while IFS=': ' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    value="$(echo "$value" | tr -d ' ')"
    case "$key" in
      loop_threshold)    [[ -n "${HEARTBEAT_LOOP_THRESHOLD:-}" ]]  || HB_LOOP_THRESHOLD="$value" ;;
      stall_timeout)     [[ -n "${HEARTBEAT_STALL_TIMEOUT:-}" ]]   || HB_STALL_TIMEOUT="$value" ;;
      error_threshold)   [[ -n "${HEARTBEAT_ERROR_THRESHOLD:-}" ]] || HB_ERROR_THRESHOLD="$value" ;;
      context_pct)       [[ -n "${HEARTBEAT_CONTEXT_PCT:-}" ]]     || HB_CONTEXT_PCT="$value" ;;
      max_nudges)        [[ -n "${HEARTBEAT_MAX_NUDGES:-}" ]]      || HB_MAX_NUDGES="$value" ;;
      window_size)       [[ -n "${HEARTBEAT_WINDOW_SIZE:-}" ]]     || HB_WINDOW_SIZE="$value" ;;
      dry_run)           [[ -n "${HEARTBEAT_DRY_RUN:-}" ]]         || HB_DRY_RUN="$value" ;;
      allowlist)         [[ -n "${HEARTBEAT_ALLOWLIST:-}" ]]       || HB_ALLOWLIST="$value" ;;
      webhook_url)       HB_WEBHOOK_URL="$value" ;;
    esac
  done < "$config_file"
}

# Load team config after defaults (env vars still override)
_load_team_config
