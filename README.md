# Heartbeat

Watchdog plugin that detects stuck, looping, or stalled AI coding agents and nudges them back on track.

Zero-config. Zero LLM cost. Just pattern matching.

Works with **Claude Code** and **GitHub Copilot CLI**.

## Install

**Claude Code:**
```bash
claude plugin install matantsach/heartbeat
```

**GitHub Copilot CLI:**
```bash
copilot plugin install matantsach/heartbeat
```

That's it. No config file needed. Heartbeat starts watching immediately.

## What It Detects

| Pattern | Name | Trigger |
|---------|------|---------|
| Same file edited N+ times | **Edit-Undo Cycle** | Rolling window fingerprint match |
| Same search repeated N+ times | **Grep Spiral** | Rolling window fingerprint match |
| Same failing command retried N+ times | **Permission Hammer** | Rolling window fingerprint match |
| N+ consecutive tool failures | **Error Cascade** | Consecutive error counter |
| Context window usage > threshold | **Context Cliff** | Cumulative output byte tracking |
| No tool activity for N seconds | **Stall** | Background timer + desktop notification |

## How It Works

```
PostToolUse → detect pattern → set intervention flag
    ↓
PreToolUse (next call) → read flag → block tool (exit 2)
    ↓
Agent sees: "Heartbeat: Edit-Undo Cycle detected. You've edited
'src/auth.ts' 3+ times. Try a different approach."
    ↓
Agent adjusts strategy automatically
```

**Escalation ladder:**
1. **Nudge** — block tool call with actionable message (agent self-corrects)
2. **Notification** — desktop alert after max nudges (human intervenes)
3. **Tombstone** — write failure context so restarted agents don't repeat the mistake

## Configuration

All settings via environment variables. Defaults work out of the box.

| Variable | Default | Description |
|----------|---------|-------------|
| `HEARTBEAT_LOOP_THRESHOLD` | `3` | Repeated fingerprints before detection |
| `HEARTBEAT_STALL_TIMEOUT` | `120` | Seconds of inactivity before stall alert |
| `HEARTBEAT_ERROR_THRESHOLD` | `5` | Consecutive failures before error cascade |
| `HEARTBEAT_CONTEXT_PCT` | `80` | Context usage % before pressure warning |
| `HEARTBEAT_MAX_NUDGES` | `3` | Nudges before escalating to notification |
| `HEARTBEAT_WINDOW_SIZE` | `20` | Tool calls tracked in rolling window |
| `HEARTBEAT_DRY_RUN` | `0` | Set to `1` to detect without blocking |
| `HEARTBEAT_ALLOWLIST` | _(empty)_ | Comma-separated fingerprints to skip (e.g. `Bash:npm test,Read:*`) |
| `HEARTBEAT_WEBHOOK_URL` | _(empty)_ | URL to POST intervention events (Slack, PagerDuty, etc.) |
| `HEARTBEAT_CI` | _(auto)_ | Set to `1` for CI mode (auto-detected from `CI` env var) |

### Team Config

Check in a `.heartbeat.yml` to share settings across your team:

```yaml
# .heartbeat.yml
loop_threshold: 5
stall_timeout: 180
error_threshold: 10
max_nudges: 5
dry_run: 0
allowlist: Bash:npm test,Bash:npm run build
webhook_url: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

Environment variables override `.heartbeat.yml` values.

## Dry-Run Mode

Run Heartbeat in observe-only mode to evaluate before enabling enforcement:

```bash
HEARTBEAT_DRY_RUN=1 claude
```

Heartbeat detects and logs all patterns but never blocks. Session summary shows `(dry-run)`. Review `.heartbeat/incidents.jsonl` to tune thresholds before going live.

## CI/CD Mode

When `CI=true` (auto-detected) or `HEARTBEAT_CI=1`:

- Writes machine-readable `.heartbeat/result.json`
- Skips desktop notifications
- Still blocks tool calls (agents fail fast)

```json
{"status":"blocked","pattern":"edit-undo-cycle","message":"...","intervention_count":1}
```

## Webhooks

POST intervention events to Slack, PagerDuty, or any endpoint:

```bash
HEARTBEAT_WEBHOOK_URL=https://hooks.slack.com/services/T.../B.../xxx claude
```

Payload:
```json
{
  "event": "intervention",
  "pattern": "edit-undo-cycle",
  "message": "...",
  "timestamp": "2026-03-14T10:30:00Z",
  "host": "dev-laptop",
  "cwd": "/home/user/project"
}
```

## Session Tombstones

When an agent is stuck beyond recovery (max nudges exceeded), Heartbeat writes a tombstone to `.heartbeat/tombstones/`. On the next session start, the agent sees:

```
Heartbeat: Previous session died from 'edit-undo-cycle'.
Avoid repeating: You've edited 'src/auth.ts' 3+ times...
```

This prevents the restarted agent from walking into the same wall.

## Session Output

```
Heartbeat: 47 tool calls, 12m, no issues
Heartbeat: 93 tool calls, 28m, 2 interventions
Heartbeat: 15 tool calls, 3m, 1 intervention (dry-run)
```

## Incident Log

All events logged to `.heartbeat/incidents.jsonl`:

```json
{"timestamp":"2026-03-14T10:30:00Z","pattern":"edit-undo-cycle","action":"tool_blocked","details":"...","tool_call_number":15}
```

## Custom Patterns

Add pattern files to `.heartbeat/patterns/` in your project:

```json
{
  "name": "docker-rebuild-loop",
  "display_name": "Docker Rebuild Loop",
  "description": "Agent keeps rebuilding Docker image without changing Dockerfile",
  "tools": ["Bash"],
  "nudge": "You've run docker build {threshold}+ times. Check the Dockerfile or build args first.",
  "severity": "high"
}
```

Heartbeat loads custom patterns automatically alongside built-in ones.

## Platform Support

| Feature | Claude Code | Copilot CLI |
|---------|:-----------:|:-----------:|
| Loop detection | yes | yes |
| Stall detection | yes | yes |
| Error spiral | yes | yes |
| Context pressure | yes | yes |
| PreToolUse blocking | yes | yes |
| Desktop notifications | yes | yes |
| Webhook integration | yes | yes |
| CI/CD mode | yes | yes |
| Subagent monitoring | — | yes |

## Architecture

```
┌─────────────────────────────────────────┐
│          Platform Adapters              │
│  .claude-plugin/    plugin.json         │
│  (Claude Code)      (Copilot CLI)       │
└──────────────┬──────────────────────────┘
               │ same bash scripts
┌──────────────┴──────────────────────────┐
│           Hook Scripts                  │
│  session-start.sh → init + stall timer  │
│  post-tool-use.sh → detect + flag       │
│  pre-tool-use.sh  → block + nudge       │
│  session-end.sh   → summary + cleanup   │
└──────────────┬──────────────────────────┘
               │
┌──────────────┴──────────────────────────┐
│           Core Libraries                │
│  config.sh  state.sh  detect.sh         │
│  log.sh     notify.sh                   │
└─────────────────────────────────────────┘
```

## Testing

```bash
./test/run-tests.sh
```

12 test suites, 111+ assertions.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The easiest way to contribute is adding a new [detection pattern](patterns/).

## License

[MIT](LICENSE)
