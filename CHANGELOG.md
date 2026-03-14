# Changelog

## [0.2.1](https://github.com/matantsach/heartbeat/compare/v0.2.0...v0.2.1) (2026-03-14)


### Bug Fixes

* Copilot CLI plugin compatibility ([#6](https://github.com/matantsach/heartbeat/issues/6)) ([736706f](https://github.com/matantsach/heartbeat/commit/736706f56a50fb8d65ef4b0e7e4c17f5830490c6))
* make hooks work natively in Copilot CLI ([#7](https://github.com/matantsach/heartbeat/issues/7)) ([c7ebf2f](https://github.com/matantsach/heartbeat/commit/c7ebf2f1de90ffeaf91647445d3b237ab825416f))


### Miscellaneous

* add open source community files ([#4](https://github.com/matantsach/heartbeat/issues/4)) ([e86ea8b](https://github.com/matantsach/heartbeat/commit/e86ea8bf593f676703f6176501774d8059641d26))

## [0.2.0](https://github.com/matantsach/heartbeat/compare/v0.1.0...v0.2.0) (2026-03-14)


### Features

* fix stall timer persistence + content-aware fingerprinting ([2e9eccf](https://github.com/matantsach/heartbeat/commit/2e9eccf35291e56f7d4b3d98b019a596d9fee2cc))
* fix stall timer persistence and add content-aware fingerprinting ([31fd4b6](https://github.com/matantsach/heartbeat/commit/31fd4b6949de101b3995c2295a300ab76a566c74))


### Bug Fixes

* add shellcheck disable for intentional glob matching in allowlist ([8583721](https://github.com/matantsach/heartbeat/commit/8583721029f8e015d63a8844f0936d96c0d6ddf0))


### CI

* add CI/CD pipeline with release-please automation ([99b557d](https://github.com/matantsach/heartbeat/commit/99b557dda5eac004dea222c9a1b2a9643f330c9d))

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
