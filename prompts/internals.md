---
description: How matato pi works
---

# Internals
This is all information you need to know to work with matato-pi.

## Env Vars

**WORKSPACE**: Folder where all projects/repositories are located
**MATATO_PI_CONFIG**: Folder where to save configurations, plans, researches and more data related to matato-pi

## Automations

Manage automations through the local web API. Set `api=http://localhost:4000/api/automations` unless `MATATO_PI_WEB_URL` points to another server.

Read all:

```sh
curl -sS "$api"
```

Read one:

```sh
curl -sS "$api/42"
```

Create:

```sh
curl -sS -X POST "$api" -H 'content-type: application/json' -d '{
  "job_name": "daily-review",
  "enabled": true,
  "schedule": "0 9 * * *",
  "user_prompt": "Review open work.",
  "daily_session": false,
  "model": "your-model",
  "thinking_level": "low",
  "can_launch_sub_agents": false
}'
```

Update:

```sh
curl -sS -X PUT "$api/42" -H 'content-type: application/json' -d '{
  "job_name": "daily-review",
  "enabled": true,
  "schedule": "0 10 * * *",
  "user_prompt": "Review open work.",
  "daily_session": false,
  "model": "your-model",
  "thinking_level": "low",
  "can_launch_sub_agents": false
}'
```

Delete:

```sh
curl -sS -X DELETE "$api/42"
```
