---
description: How matato pi works
---

# Internals
This is all information you need to know to work with matato-pi.

## Env Vars

**WORKSPACE**: Folder where all projects/repositories are located
**MATATO_PI_CONFIG**: Folder where to save configurations, plans, researches and more data related to matato-pi

## Bots

Manage bots through the local web API. Set `api=http://localhost:4000/api/bots` unless `MATATO_PI_WEB_URL` points to another server.

| Field | Required | Purpose |
| --- | --- | --- |
| `name` | Yes | Display name and agent identity. |
| `role` | Yes | The bot's working role. |
| `description` | Yes | Instructions defining its work. |

Create generates the bot's chat and background session IDs. Reads return them, but updates only accept the three profile fields above.

Read all:

```sh
curl -sS "$api"
```

Read one:

```sh
curl -sS "$api/$botId"
```

Create:

```sh
curl -sS -X POST "$api" -H 'content-type: application/json' -d '{
  "name": "Research",
  "role": "researcher",
  "description": "Find reliable answers and summarize them concisely."
}'
```

Update:

```sh
curl -sS -X PUT "$api/$botId" -H 'content-type: application/json' -d '{
  "name": "Research",
  "role": "researcher",
  "description": "Find reliable answers and cite the relevant sources."
}'
```

Delete:

```sh
curl -sS -X DELETE "$api/$botId"
```

## Messages

Send a bot-to-bot message through the local web API. Set `api=http://localhost:4000/api/messages` unless `MATATO_PI_WEB_URL` points to another server. Discover bots and their IDs with `GET /api/bots` first (see Bots). The sender is always a bot; the API forces `sender_type` to `bot`.

| Field | Required | Purpose |
| --- | --- | --- |
| `receiver_bot_id` | Yes | Existing bot ID that receives the message. |
| `sender_id` | Yes | Your bot ID; must be an existing bot. |
| `kind` | Yes | Message kind, for example `request`, `result`, or `note`. |
| `content` | Yes | Message body delivered to the receiver. |

Delivery is asynchronous: a successful create returns `201` with a pending message, and a background worker injects it as a normal prompt (`Internal <kind> from <sender>:`) into the receiver's chat session once that session is free. The receiver answers by sending a message back with the roles reversed. Unknown receiver or sender IDs return `422`. Automation results use the same pipeline internally but are delivered to the bot's background session instead.

Send:

```sh
curl -sS -X POST "$api" -H 'content-type: application/json' -d '{
  "receiver_bot_id": "receiver-bot-uuid",
  "sender_id": "your-bot-uuid",
  "kind": "request",
  "content": "Summarize the open issues and send me the result."
}'
```

## Automations

Manage automations through the local web API. Set `api=http://localhost:4000/api/automations` unless `MATATO_PI_WEB_URL` points to another server. An automation without `bot_id`, including one with `bot_id: null`, is a workspace automation. A bot automation has that bot's `bot_id` and runs with its identity. Every create and update sends all fields below.

| Field | Required | Default | Purpose |
| --- | --- | --- | --- |
| `bot_id` | No | `null` | Existing bot ID for a bot automation; `null` for a workspace automation. |
| `job_name` | Yes | None | Unique automation name. Also names the Pi agent and optional skill. |
| `enabled` | Yes | `true` | Schedules the job when true. |
| `schedule` | Yes | None | Five- or six-field cron expression. |
| `user_prompt` | Yes | None | Prompt sent to Pi. |
| `daily_session` | Yes | `false` | Reuses one Pi session per day for this job. |
| `can_overlap` | Yes | `false` | Allows a new run while the previous run is still active. |
| `model` | Yes | None | Pi model identifier. |
| `thinking_level` | Yes | None | Pi reasoning level. |
| `can_launch_sub_agents` | Yes | `false` | Allows Pi sub-agents. |
| `monitor` | Yes | `false` | Registers each launched agent remotely. Active runs appear under Automations in the web UI, without a transcript. |
| `use_skill` | Yes | `false` | Loads the skill named by `job_name` and runs its optional scripts. |

Read all:

```sh
curl -sS "$api"
```

Read one:

```sh
curl -sS "$api/42"
```

Create a bot automation:

```sh
curl -sS -X POST "$api" -H 'content-type: application/json' -d '{
  "bot_id": "bot-uuid-from-get-bots",
  "job_name": "daily-review",
  "enabled": true,
  "schedule": "0 9 * * *",
  "user_prompt": "Review open work.",
  "daily_session": false,
  "can_overlap": false,
  "model": "your-model",
  "thinking_level": "low",
  "can_launch_sub_agents": false,
  "monitor": false,
  "use_skill": false
}'
```

Update:

```sh
curl -sS -X PUT "$api/42" -H 'content-type: application/json' -d '{
  "bot_id": "bot-uuid-from-get-bots",
  "job_name": "daily-review",
  "enabled": true,
  "schedule": "0 10 * * *",
  "user_prompt": "Review open work.",
  "daily_session": false,
  "can_overlap": false,
  "model": "your-model",
  "thinking_level": "low",
  "can_launch_sub_agents": false,
  "monitor": false,
  "use_skill": false
}'
```

Delete:

```sh
curl -sS -X DELETE "$api/42"
```
