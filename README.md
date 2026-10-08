# Matato Pi

Matato Pi extends [Pi](https://github.com/earendil-works/pi) with coding skills, prompts, subagents, scheduled automations, direct Telegram and Discord channels, and an optional web app for remote sessions and automation management.

It works as a Pi package: Pi loads the extensions, skills, and prompts declared in `package.json`. The web app starts Pi in RPC mode, stores automation and remote-session metadata in SQLite, and keeps Pi JSONL files as the conversation history.

## Install

Install the package in Pi:

```bash
pi install /absolute/path/to/matato-pi
```

Or install it from Git:

```bash
pi -e git:github.com/<owner>/matato-pi
```

Set these variables when using the matching features:

```bash
export WORKSPACE=/absolute/path/to/projects
export TELEGRAM_BOT_TOKEN=your-token
export TELEGRAM_OWNER_ID=your-chat-id
export DISCORD_BOT_TOKEN=your-discord-bot-token
export DISCORD_GUILD_ID=your-server-id
export DISCORD_CHANNEL_IDS=comma-separated-channel-ids
export TAVILY_API_KEY=your-tavily-api-key
```

`TAVILY_API_KEY` enables the web-search skill; create a key at [Tavily](https://app.tavily.com). `MATATO_PI_CONFIG` optionally changes the data directory; it defaults to `~/.config/matato-pi`.

## Web app

The Phoenix app provides remote Pi sessions and automations. Telegram and Discord extensions send directly and do not require the web app.

```bash
cd web-app
WORKSPACE=/absolute/path/to/projects mix setup
WORKSPACE=/absolute/path/to/projects mix phx.server
```

Open `http://localhost:4000`. Its SQLite database is `$MATATO_PI_CONFIG/matato-pi.sqlite3`.

Set `WEB_APP_TIME_ZONE` to change the application's time zone (default `Europe/Berlin`), for example `WEB_APP_TIME_ZONE=America/New_York mix phx.server`.

### LiveDashboard

LiveDashboard exposes Phoenix, LiveView, Ecto/SQLite, and VM metrics at `/dashboard`, with `/dev/dashboard` also available in development. Destructive dashboard actions are disabled. For remote access, use authenticated TLS ingress and allow WebSocket upgrades for `/dashboard/livewebsocket`.

## API

The web app exposes JSON CRUD endpoints for automations:

```text
GET, POST                 /api/automations
GET, PUT, DELETE          /api/automations/:id
POST                      /api/sessions
```

`POST /api/sessions` with an empty object starts a general session. With `relative_project`, it registers an external session (see `/remote` below), accepting `name`, `session_file`, and `pi_session_id`.

The API has no built-in authentication. Keep the server private or place authenticated TLS ingress in front of it.

## Remote sessions

The new-session screen offers a general session or a workspace project. General sessions start in `MATATO_PI_CONFIG`, not a repository. Pi requires a working directory, so these are project-independent, not literally folderless.

Run `/remote [name]` in an interactive Pi session to register it in the local web app so it appears in the session list on your phone. Without a name, the project directory name is used. The web app URL is read from `MATATO_PI_WEB_URL` and defaults to `http://localhost:4000`. Ephemeral sessions cannot be registered. Running `/remote` again on the same session updates the existing entry.

To hand a laptop session off to a server, run `/remote [name] --host <sshHost>`, for example `/remote "My session" --host piServer`. Matato creates `~/.pi/agent/sessions` on that SSH host, copies the active session file there, then registers it at `http://<sshHost>:4000`. The remote server must run the Matato web app as the SSH user and allow the laptop to reach port 4000 through the SSH host name. Configure non-default hostnames, users, ports, and a non-interactive identity file in `~/.ssh/config`; `<sshHost>` must be an SSH config host name, not SSH options. If those prerequisites are unavailable, use `/remote [name]` to keep local registration.

A registered session must not be driven from the terminal and the phone at the same time: both write to the same Pi session file, so concurrent use corrupts the conversation history.

## Direct channels

Telegram and Discord are outbound only: no inbox ingestion, polling, or channel cron. Configure the required environment variables in the Pi process that sends messages. Extensions call each channel's API directly; there are no web-app switches or channel settings stored in the database.

Telegram requires `TELEGRAM_BOT_TOKEN` and `TELEGRAM_OWNER_ID`. `telegram_send_message` sends only to that owner, with a 4096-character limit after newline normalization. Discord requires `DISCORD_BOT_TOKEN`, `DISCORD_GUILD_ID`, and comma-separated `DISCORD_CHANNEL_IDS`. `discord_send_message` verifies the allowlisted channel and guild on every send, disables automatic mentions, and accepts an optional `replyTo` message ID. Threads must be explicitly allowlisted; DMs are unsupported.

Missing credentials or invalid destinations block delivery. HTTP requests have a 15-second timeout; an uncertain delivery is not retried automatically. Errors do not expose credentials or raw network details. `MATATO_PI_WEB_URL` is not used for channel sends.

Use the `telegram` and `discord` skills for owner-requested messages or approved notifications. They have no pre/post scripts. Schedule notifications through ordinary user automations, with channel environment variables set in the worker or web-app process so its Pi children inherit them. Review outgoing text for secrets. Neither tool posts Pi's final response automatically.

## Automations

### TypeScript worker (no Elixir required)

The original Croner-based worker is restored from `worker/index.ts` (introduced in `f14f1e3`, removed in `3a90990`). It reads local JSON and runs Pi directly; no web app, database, or HTTP API is needed.

```text
config.json → Croner → optional preScript.ts → Pi → optional postScript.ts
```

Install Bun and Pi, then configure and start the worker:

```bash
npm install
mkdir -p "${MATATO_PI_CONFIG:-$HOME/.config/matato-pi}/automations"
cp extras/automations.json "${MATATO_PI_CONFIG:-$HOME/.config/matato-pi}/automations/config.json"
# Edit the file: choose a real model and set enabled to true.
npm run worker
```

The JSON uses camelCase fields (`jobName`, `userPrompt`, `dailySession`, `canOverlap`, `thinkingLevel`, `canLaunchSubAgents`, `useSkill`), unlike the web API. See `extras/automations.json` for a safe, disabled example. `MATATO_PI_AUTOMATIONS_CONFIG` overrides the file path; otherwise it is `$MATATO_PI_CONFIG/automations/config.json`. Five- and six-field cron schedules are supported. The worker reloads edits every five seconds and retains existing schedules if a replacement is invalid. Missing configuration means no jobs; deleting the file stops future runs, and the worker stays running for later edits.

`useSkill: false` runs a prompt without a skill. Skill jobs resolve `~/.pi/agent/skills/<jobName>` before the package's bundled skills and run optional `scripts/preScript.ts` and `scripts/postScript.ts` with Bun. Empty pre-script output skips Pi. Historical configs default to `useSkill: true` and `canOverlap: false`. Set Telegram/Discord credentials in the worker's environment for approved notifications.

Local jobs are independent of web-app automations: SQLite jobs are not automatically imported, and `monitor`/web run history are not supported by the worker; omit `monitor` or set it to false (enabled monitored jobs are rejected). Do not schedule the same job in both runners. `/automations` reads only this local configuration, never the web API. A missing file shows an empty list; press `r` to reload after editing it.

### Web-app automations

Create a standalone automation from the web app or ask your agent to do it. It runs a prompt on a cron schedule using the automation's required `model` and `thinking_level` settings. `use_skill` loads the skill named by `job_name`; optional `scripts/preScript.ts` output is added to the agent context. After Pi completes, optional `scripts/postScript.ts` runs; failure fails the automation. `daily_session` reuses one Pi session per day, `can_overlap` permits concurrent runs, and `monitor` shows the job in the web app. `/automations` in Pi shows only local config jobs, not web-app jobs. Automations send notifications through the same environment-configured extensions as interactive sessions.

## Upgrade

Back up `$MATATO_PI_CONFIG/matato-pi.sqlite3` before migrating. The migration removes bot profiles and the internal message queue, detaches automations from bots, and retires legacy `telegram-inbox`/`discord` skill polling jobs. Other automations and all session metadata/transcript files remain. Historical bot conversations reopen as workspace sessions. Removed profiles, queued messages, and polling jobs cannot be recovered by rolling migrations back. A follow-up migration drops the unused `channel_settings` table; channel sends no longer consult the web app.

## Contribute

Install Node dependencies and run the package checks:

```bash
npm install
npm run check
npm run lint
npm test
```

Run a fresh Atlas report with a zero-findings gate (requires [uv](https://docs.astral.sh/uv/) and `jq`):

```bash
npm run atlas                     # Analyze this repository, including web-app
npm run atlas -- /path/to/project  # Analyze another folder
# Override the sibling Atlas Python project location when using a worktree:
ATLAS_PROJECT=/path/to/atlas/atlas npm run atlas
```

`ATLAS_PROJECT` defaults to `../atlas/atlas`, the Python project in a sibling `atlas` checkout, relative to the working directory. The command prints Atlas's JSON report and exits nonzero for any findings, analysis failure, or invalid report. It uses `--skip-save` so it never writes to the Atlas database. Local `.atlasignore` rules still apply.

For the web app, install Elixir/Erlang and run:

```bash
cd web-app
mix setup
MIX_ENV=test mix precommit
```

Build a production web release with `cd web-app && bin/deploy`. Set `SECRET_KEY_BASE`, `PHX_HOST`, and `WORKSPACE` before starting it with `MIX_ENV=prod mix phx.server`.
