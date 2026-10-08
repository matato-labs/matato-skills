---
name: internals
description: How Matato Pi works. Use when managing automations, their local JSON config, workers, or direct channel setup.
---

# Internals

`WORKSPACE` is the projects directory. `MATATO_PI_CONFIG` holds Matato configuration and state (default `~/.config/matato-pi`). Pi JSONL files retain conversation history.

## Automations

Use local config for requests to list, create, update, pause, or delete automations. `/automations` is a read-only config browser, not an editor or scheduler.

Run `npm run worker` from the package to schedule jobs. Manage `$MATATO_PI_CONFIG/automations/config.json` (default `~/.config/matato-pi/automations/config.json`), or the file selected by `MATATO_PI_AUTOMATIONS_CONFIG`. It contains `{ "automations": [...] }` with camelCase fields: `jobName`, `enabled`, `schedule`, `userPrompt`, `dailySession`, `canOverlap`, `model`, `thinkingLevel`, `canLaunchSubAgents`, `useSkill`. `extras/automations.json` is a disabled template; set a real model and enable the job. Croner supports five or six fields and uses the process time zone. Edits reload every five seconds; invalid schedules retain the previous jobs.

Read the resolved config before editing; preserve unrelated jobs and fields. Create the parent directory and `{ "automations": [] }` only if the file is missing; do not overwrite invalid JSON. Identify jobs by unique `jobName`. Use camelCase fields and a configured Pi model; ask if the model or schedule/time zone is unclear. Set `useSkill: false` explicitly for plain prompt jobs; with `useSkill: true`, `jobName` must name an installed skill. Escape multiline prompts with `\n` in JSON. Disable jobs with `enabled: false`; delete only the requested entry. Neither change cancels an in-flight run.

Confirm the worker is running before claiming a job is scheduled: editing config alone does not start it. It inherits the process time zone and channel credentials. Verify saved JSON and report the config path and changes; `/automations` reloads separately with `r`.

`useSkill` defaults to true for historical configs, and `canOverlap` defaults to false. Skill jobs resolve the user's skills before bundled skills. Optional `scripts/preScript.ts` output becomes run context; empty output skips Pi. After Pi succeeds, optional `scripts/postScript.ts` runs, and script failures fail the job. Monitoring is unsupported; omit `monitor` or set it to false (enabled monitored jobs are rejected). `/automations` reads only the local configuration. A missing file shows an empty list; press `r` to reload after edits.

## Direct channels

Telegram and Discord extensions send directly to their external APIs. There is no channel inbox ingestion, polling, or channel cron. Telegram and Discord skills have no pre/post scripts. User automations may send owner-approved notifications through the direct tools.

Telegram requires `TELEGRAM_BOT_TOKEN` and `TELEGRAM_OWNER_ID`; Discord requires `DISCORD_BOT_TOKEN`, `DISCORD_GUILD_ID`, and `DISCORD_CHANNEL_IDS`. Configure these in the sending Pi process; automation jobs inherit them from the worker. Missing credentials or invalid destinations block delivery.

Telegram transport restricts delivery to the owner. Discord verifies its guild/channel allowlists and disables automatic mentions; the destination allowlist is not an owner identity check. See `skills/telegram/SKILL.md` and `skills/discord/SKILL.md` for direct-send policies.
