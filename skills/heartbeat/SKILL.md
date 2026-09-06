---
name: heartbeat
description: Run a quiet Matato health check from deployment and agent activity signals.
disable-model-invocation: true
---

# Heartbeat Skill

## Purpose

Run a scheduled health check for Matato. Use the `short-term-memory` skill to inspect recent deploy and session activity, verify that the deployed worker appears healthy, and decide whether the findings require a GitHub issue or only a Telegram notification.

## Tools and skills

- github-issues
- ghcli
- telegram

## Inputs

### Environment variables

- `$STORAGE_PATH` is an environment variable. Resolve it through the shell before using file tools.

### Sources

- `$STORAGE_PATH/agent/deploy.log`
- `$STORAGE_PATH/agent/sessions/matato/`

## Workflow

1. Keep the analysis focused on the last hour.
2. Resolve `$STORAGE_PATH` through the shell before reading from runtime storage.
3. Read recent entries in `$STORAGE_PATH/agent/deploy.log`.
4. Inspect recent session files under `$STORAGE_PATH/agent/sessions/matato/heartbeat/`.
5. If needed, inspect nearby recent sessions under `$STORAGE_PATH/agent/sessions/matato/` for more context.
6. Use the `short-term-memory` skill to extract evidence and summarize what happened.
7. Look for deployment failures, crashes, repeated runtime errors, missing or stale startup signals, stalled jobs, or other anomalies that require attention.
8. Ignore healthy logs, old resolved errors, and isolated noise.
9. If there is an actionable bug or persistent anomaly that needs code or configuration follow-up, create a GitHub issue with the `github-issues` skill.
10. If the finding is informational only, notify the user with the `telegram` skill.
11. If there is no meaningful issue, stop quietly.
