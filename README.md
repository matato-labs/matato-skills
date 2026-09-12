# Matato Pi Package

MatatoPi is a pi package with extensions, skills promps that could help to have a nice e2e workflow to write code AI using pi. It has an extra feature to scheudled work direactly linked to a skill and allows you to run deterministic scripts before the AI workflow trigger.

```bash
pi install /absolute/path/to/matato-pi
```
> You can install from github as well `pi -e git:github.com/user/repo`

## Environment variables

| Variable | Required by | Description |
| --- | --- | --- |
| `TELEGRAM_BOT_TOKEN` | Telegram | Bot API token. |
| `TELEGRAM_OWNER_ID` | Telegram | Owner chat ID allowed to use the inbox and receive replies. |
| `WORKSPACE` | Workspace skills | Directory containing your repositories. |

## Remote Agent Web App

A database-free Phoenix LiveView client for `pi --mode rpc` lives in [`web-app/`](web-app/README.md).

## Features
* Subagents, including bounded parallel batches
* Scheduled jobs
* Plans and researches storage in local files
* E2E software lifecycle skills
* Prepare for AI assistant work
* Telegram two-way connection

## Development

### Test, Linting, Formating...
```bash
npm run test
npm run lint
npm run check
```

## Examples

### Subagents

`subagent` accepts its existing single-task form with `prompt` and optional `cwd`. For independent work, use `tasks` instead; the modes are mutually exclusive. Batches accept up to 16 tasks and run no more than four child Pi processes at once. Progress shows aggregate completion while every task's ordered success or failure is retained in the final tool result.

```json
{
  "tasks": [
    { "prompt": "Review the API changes." },
    { "prompt": "Review the test coverage.", "cwd": "/path/to/project" }
  ]
}
```

Cancelling a batch stops every running child. A failed task is reported alongside, rather than replacing, successful sibling outputs.

### Plans
You can see all plans you have created with matato-pi with `/plans`, plans are stored in `~/.config/matato-pi/plans/{repo}/{name}.md`

### Researches
Researches are under `/researches` and they are stored in `~/.config/matato-pi/researches/{name}.md`


### Scheduled jobs
Scheduled jobs are configured via `$MATATO_PI_CONFIG/automations/config.json` (default: `~/.config/matato-pi/automations/config.json`). The web app loads and schedules them. `canOverlap` defaults to `false`; set it to `true` to allow a new run of the same automation before its previous run finishes. An automation can run `{skillName}/scripts/preScript.ts` beforehand; non-empty output is included as automation context.

To create/read/update/delete cron jobs, use `/automations`.
### Telegram
Add this automation through `/automations`:

```json
{
  "jobName": "telegram-inbox",
  "enabled": true,
  "schedule": "*/3 * * * * *",
  "userPrompt": "Process the new Telegram messages.",
  "dailySession": true,
  "canOverlap": false,
  "model": "your-model",
  "thinkingLevel": "low",
  "canLaunchSubAgents": false
}
```

Each day uses one continuous Pi session in Pi's default session directory (`~/.pi/agent/sessions`, or `PI_CODING_AGENT_SESSION_DIR`). Empty polls skip Pi entirely. The inbox accepts messages only from `TELEGRAM_OWNER_ID`; agents reply through `telegram_send_message`.
