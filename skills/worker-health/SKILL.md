---
name: worker-health
description: Run a Matato worker health check using the CLI and process signals instead of deploy.log or raw SQL.
---

# Worker Health Skill

## When to Use

- The heartbeat skill is unavailable or noisy because `deploy.log` is missing.
- You need a quick, CLI-based health check for the Matato worker and scheduled jobs.
- You want to verify worker state before deciding whether to create a GitHub issue.

## Tools and skills

- bash
- github-issues (only when an actionable bug is found)

## Inputs

- `$STORAGE_PATH` environment variable for the runtime directory.

## Workflow

1. Resolve `$STORAGE_PATH` through the shell.
2. Verify the worker process is running with `pgrep -f matatoWorker`.
3. Verify the CLI can bootstrap by running `matato --json job list`.
4. Check recent session directories under `$STORAGE_PATH/agent/sessions/matato/`. Look for:
   - Sessions newer than the last hour for the current scheduled jobs.
   - Repeated failures or errors in recent session files.
5. If `deploy.log` exists, read the tail for supplemental context. Do not fail if it is missing.
6. If an actionable bug is found (worker process missing, CLI cannot bootstrap, repeated scheduled job failures), create a GitHub issue with `github-issues`.
7. If everything is healthy, stop quietly.

## Core Rules

- Do not run raw SQL queries against `matato.sqlite`.
- Do not treat a missing `deploy.log` as a failure by itself.
- Use the Matato CLI for runtime state; do not invent repository commands.

## Example Commands

```bash
# Verify the worker process
pgrep -af matatoWorker

# Verify CLI bootstrap and list scheduled jobs
matato --json job list

# Optional: inspect recent sessions
ls -lt "$STORAGE_PATH/agent/sessions/matato/" | head -20
```
