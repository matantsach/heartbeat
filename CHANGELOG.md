# Changelog

## [0.1.0] - 2026-03-14

### Added

**Core Detection (4 modes):**
- Edit-Undo Cycle — detects repeated edits to the same file
- Grep Spiral — detects repeated searches with similar patterns
- Permission Hammer — detects retried failing commands
- Error Cascade — detects consecutive tool failures
- Context Cliff — detects context window pressure exceeding threshold
- Stall detection — background timer alerts on inactivity

**Response System:**
- PreToolUse blocking with pattern-specific nudge messages
- Graduated escalation (nudge -> desktop notification after max nudges)
- Session tombstones — restarted agents know what killed their predecessor

**Observability:**
- Session-end summary one-liner
- JSONL incident log (.heartbeat/incidents.jsonl)
- First-run demo on install

**Configuration:**
- Zero-config defaults with env var overrides
- Team config via .heartbeat.yml
- Allowlisted patterns to suppress false positives
- Dry-run / observe-only mode

**Platforms:**
- Claude Code (CCPI plugin)
- GitHub Copilot CLI (plugin)

**CI/CD:**
- CI mode with machine-readable result.json
- Webhook integration for Slack/PagerDuty/custom endpoints

**Ecosystem:**
- Named pattern files (JSON, extensible)
- User custom patterns via .heartbeat/patterns/
- 12 test suites, 111+ assertions
