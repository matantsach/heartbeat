# Contributing to Heartbeat

Thanks for your interest in contributing! Heartbeat is a simple project by design — bash + jq, no build step, no dependencies.

## Quick Start

```bash
# Clone
git clone https://github.com/mtsach/heartbeat.git
cd heartbeat

# Run tests
./test/run-tests.sh

# Test locally with Claude Code
claude --plugin-dir . --debug
```

## Adding a Detection Pattern

The easiest way to contribute is by adding a new failure mode pattern.

1. Create a JSON file in `patterns/`:

```json
{
  "name": "my-pattern-name",
  "display_name": "Human-Readable Name",
  "description": "When this pattern occurs and why it's bad",
  "tools": ["ToolName"],
  "nudge": "Message shown to the agent. Use {target}, {threshold}, {context_pct} placeholders.",
  "severity": "low|medium|high|critical|warning"
}
```

2. Add detection logic in `scripts/lib/detect.sh` if the pattern needs a new classifier (most patterns reuse the existing fingerprint counter).

3. Add a test in `test/`.

4. Submit a PR.

## Adding Custom Patterns (Users)

Users can add patterns without contributing upstream by placing JSON files in `.heartbeat/patterns/` in their project root. Heartbeat loads these automatically.

## Project Structure

```
scripts/
  lib/
    config.sh    — Environment variable defaults
    state.sh     — Rolling window state management
    detect.sh    — Pattern matching and classification
    log.sh       — Incident logging
    notify.sh    — Desktop notifications + webhooks
  post-tool-use.sh         — Detection pipeline
  post-tool-use-failure.sh — Error counting
  pre-tool-use.sh          — Intervention (PreToolUse blocking)
  session-start.sh         — Init, demo, stall timer
  session-end.sh           — Summary, cleanup
patterns/          — Built-in pattern definitions
test/              — Test suites
```

## Guidelines

- Keep it simple. Bash + jq. No external dependencies.
- Every detection pattern needs a test.
- Pattern matching only — no LLM calls for detection.
- Nudge messages should be actionable ("try X instead") not just diagnostic ("Y detected").
- False positive prevention matters more than catching edge cases.

## Reporting Issues

Open an issue with:
- Your platform (Claude Code / Copilot CLI)
- The failure mode you encountered
- Relevant excerpt from `.heartbeat/incidents.jsonl`
