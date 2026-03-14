# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 0.2.x   | Yes                |
| < 0.2   | No                 |

## Reporting a Vulnerability

If you discover a security vulnerability in Heartbeat, please report it responsibly:

1. **Do not** open a public issue.
2. Email **security@matantsach.com** with a description of the vulnerability, steps to reproduce, and any relevant configuration.
3. You will receive a response within 72 hours acknowledging the report.
4. A fix will be developed privately and released as a patch version.

## Scope

Heartbeat is a shell-based plugin that runs hook scripts in the context of AI coding agents. Security concerns include:

- **Command injection** via malicious tool input passed to shell scripts
- **Path traversal** in file paths extracted from tool input
- **Webhook payload injection** if `HEARTBEAT_WEBHOOK_URL` is set
- **State file tampering** via `.heartbeat/` directory

## Design Principles

- Heartbeat never executes tool input as code — it only reads JSON fields via `jq`
- Webhook payloads are constructed via `jq`, not string interpolation
- All file paths are quoted in shell scripts
- No network access unless `HEARTBEAT_WEBHOOK_URL` is explicitly configured
