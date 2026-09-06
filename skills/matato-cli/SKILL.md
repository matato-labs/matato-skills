---
name: matato-cli
description: Use this skill when a task depends on Matato runtime state, persisted configuration, projects, environment variables, jobs, sequences, models, or running the Matato agent from the shell.
---

# Matato CLI

Use this skill when a task depends on Matato runtime state stored in the SQLite database.

Use the installed `matato` CLI with `--json`; it is the source of truth for command syntax and structured results.

Use only the Matato CLI for runtime state changes. Use `matato project ...` for tracked projects; do not use or invent repository commands. Do not write SQL directly, do not use a generic database tool, and do not edit bootstrap seed files after the runtime database exists.

Prefer targeted CLI reads before making changes. After any CLI change, verify the result with the matching CLI show, get, list, or state command.

Return user-facing conclusions rather than raw command output unless the user asks for raw output.
