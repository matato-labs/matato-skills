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
| `OTEL_ENDPOINT` | Telemetry | Base OTLP/HTTP collector URL, such as `http://localhost:4318`. When set, Matato Pi best-effort exports metrics and lifecycle logs to `/v1/metrics` and `/v1/logs`. |

## Telemetry

Set `OTEL_ENDPOINT` to the local Grafana OTEL-LGTM collector (normally `http://localhost:4318`) to export privacy-safe prompt, token, cost, tool, result, and duration telemetry. Export failures are ignored so they cannot interrupt Pi runs. Telemetry never includes prompt or assistant text, tool arguments or results, credentials, filesystem paths, or other request content.

`matato_pi_explicit_skill_duration_seconds` measures only commands entered as `/skill:<name>`; it does not infer or measure implicit skill selection.

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
Scheduled jobs are configured via `$MATATO_PI_CONFIG/automations/config.json` (default: `~/.config/matato-pi/automations/config.json`). The web app loads and schedules them. An automation can run `{skillName}/scripts/preScript.ts` beforehand; non-empty output is included as automation context.

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

Each day uses one continuous Pi session in Pi's default session directory (`~/.pi/agent/sessions`, or `PI_CODING_AGENT_SESSION_DIR`). Empty polls skip Pi entirely. The inbox accepts messages only from `TELEGRAM_OWNER_ID`; agents reply through `telegram_send_message`.
