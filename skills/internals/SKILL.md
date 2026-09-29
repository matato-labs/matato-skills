---
name: internals
description: How matato pi works
---

# Internals

`WORKSPACE` is the projects directory. `MATATO_PI_CONFIG` holds Matato configuration and state (default `~/.config/matato-pi`). `MATATO_PI_WEB_URL` changes the web app origin (default `http://localhost:4000`). The web app manages generic Pi sessions and scheduled automations; Pi JSONL files retain conversation history. Keep the web app API private: it has no built-in authentication.

## Sessions

Open or create sessions in the web UI. General sessions start in `MATATO_PI_CONFIG`; workspace sessions start in the selected project. Pi requires a working directory. `POST /api/sessions` with an empty object starts a general session. `/remote [name]` in an interactive Pi session registers it in the web app. `POST /api/sessions` registers an external session using `name`, `relative_project`, `session_file`, and `pi_session_id`. Do not operate the same session simultaneously in two clients.

## Automations

Manage standalone automations with the local API: `api="${MATATO_PI_WEB_URL:-http://localhost:4000}/api/automations"`. `GET` lists, `GET /:id` reads, `POST` creates, `PUT /:id` updates, and `DELETE /:id` deletes. Create and update send all fields:

| Field | Purpose |
| --- | --- |
| `job_name` | Unique name and optional skill name. |
| `enabled` | Whether future runs are scheduled. Disabling does not cancel an in-flight run. |
| `schedule` | Five- or six-field cron expression. |
| `user_prompt` | Pi prompt for the run. |
| `daily_session` | Reuse one Pi session per day when true. |
| `can_overlap` | Permit concurrent runs. |
| `model` | Required Pi model identifier. |
| `thinking_level` | Pi reasoning level. |
| `can_launch_sub_agents` | Allow subagents. |
| `monitor` | Persist runs for the web UI. |
| `use_skill` | Load the skill matching `job_name` and run its scripts. |

Example (replace model with your Pi model identifier):

```sh
curl -sS -X POST "$api" -H 'content-type: application/json' -d '{
  "job_name": "dailyReview", "enabled": true, "schedule": "0 9 * * *",
  "user_prompt": "Review open work.", "daily_session": false,
  "can_overlap": false, "model": "configured-pi-model", "thinking_level": "low",
  "can_launch_sub_agents": false, "monitor": false, "use_skill": false
}'
```

With `use_skill`, optional `scripts/preScript.ts` output becomes the run context; empty output skips the agent. After successful Pi completion, optional `scripts/postScript.ts` runs. Telegram and Discord skills have no pre/post scripts. User automations schedule prompts as usual and may send owner-approved notifications through the direct tools.

## Direct channels

Telegram and Discord extensions send directly to their external APIs, independently of the web app. There are no web-app channel toggles, status checks, or persisted channel settings. There is no channel inbox ingestion, polling, or channel cron.

Telegram requires `TELEGRAM_BOT_TOKEN` and `TELEGRAM_OWNER_ID`; Discord requires `DISCORD_BOT_TOKEN`, `DISCORD_GUILD_ID`, and `DISCORD_CHANNEL_IDS`. Configure these in the sending Pi process. Web-app sessions and automations inherit them from the web-app process. Missing credentials or invalid destinations block delivery. `MATATO_PI_WEB_URL` is not used for channel sends.

Telegram transport restricts delivery to the owner. Discord verifies its guild/channel allowlists and disables automatic mentions; the destination allowlist is not an owner identity check. See `skills/telegram/SKILL.md` and `skills/discord/SKILL.md` for direct-send policies.
