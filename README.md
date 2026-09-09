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
* Subagents
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

### Plans
You can see all plans you have created with matato-pi with `/plans`, plans are stored in `~/.config/matato-pi/plans/{repo}/{name}.md`

### Researches
Researches are under `/researches` and they are stored in `~/.config/matato-pi/researches/{name}.md`


### Scheduled jobs
Scheduled jobs are configured via a json file under `~/.config/matato-pi/automations/config.json`, when you start the worker with `npm run worker`, it loads the configuration and created a cronjob for every entry. An automation is tight to an skill, they can only be executed if the skill exist, when it's tirggered, it will search for a script called `preScript.ts` under `{skillName}/scripts`, if it's present it's going to execute it and the outpt is going to be given to the skill as input.

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
  "model": "your-model",
  "thinkingLevel": "low",
  "canLaunchSubAgents": false
}
```

Each day uses one continuous Pi session under `~/.config/matato-pi/sessions` (override the root with `MATATO_PI_STORAGE_PATH` or `STORAGE_PATH`). Empty polls skip Pi entirely. The inbox accepts messages only from `TELEGRAM_OWNER_ID`; agents reply through `telegram_send_message`.
