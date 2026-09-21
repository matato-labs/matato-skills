# Matato Pi

Matato Pi extends [Pi](https://github.com/earendil-works/pi) with coding skills, prompts, subagents, scheduled automations, Telegram support, and an optional web app for remote sessions, bots, and automation management.

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
export TAVILY_API_KEY=your-tavily-api-key
```

`TAVILY_API_KEY` enables the web-search skill; create a key at [Tavily](https://app.tavily.com). `MATATO_PI_CONFIG` optionally changes the data directory; it defaults to `~/.config/matato-pi`.

## Web app

The optional Phoenix app provides remote Pi sessions, bots, and automations.

```bash
cd web-app
WORKSPACE=/absolute/path/to/projects mix setup
WORKSPACE=/absolute/path/to/projects mix phx.server
```

Open `http://localhost:4000`. Its SQLite database is `$MATATO_PI_CONFIG/matato-pi.sqlite3`.

## API

The web app exposes JSON CRUD endpoints for bots and automations:

```text
GET, POST                 /api/bots
GET, PUT, DELETE          /api/bots/:id
GET, POST                 /api/automations
GET, PUT, DELETE          /api/automations/:id
POST                      /api/sessions
```

`POST /api/sessions` registers a session started outside the web app (see `/remote` below); it accepts `name`, `relative_project`, `session_file`, and `pi_session_id`.

The API has no built-in authentication. Keep the server private or place authenticated TLS ingress in front of it.

## Remote sessions

Run `/remote [name]` in an interactive Pi session to register it in the local web app so it appears in the session list on your phone. Without a name, the project directory name is used. The web app URL is read from `MATATO_PI_WEB_URL` and defaults to `http://localhost:4000`. Ephemeral sessions cannot be registered. Running `/remote` again on the same session updates the existing entry.

To hand a laptop session off to a server, run `/remote [name] --host <sshHost>`, for example `/remote "My session" --host piServer`. Matato creates `~/.pi/agent/sessions` on that SSH host, copies the active session file there, then registers it at `http://<sshHost>:4000`. The remote server must run the Matato web app as the SSH user and allow the laptop to reach port 4000 through the SSH host name. Configure non-default hostnames, users, ports, and a non-interactive identity file in `~/.ssh/config`; `<sshHost>` must be an SSH config host name, not SSH options. If those prerequisites are unavailable, use `/remote [name]` to keep local registration.

A registered session must not be driven from the terminal and the phone at the same time: both write to the same Pi session file, so concurrent use corrupts the conversation history.

## Bots

Create a bot from the web app or asking your agent to do it. A bot has a name, role, and description; Matato creates separate durable chat and background Pi sessions and gives both its identity. Open the bot from the web app to chat with it. Add its `bot_id` to an automation to run scheduled work as that bot.

For Telegram, configure `TELEGRAM_BOT_TOKEN` and `TELEGRAM_OWNER_ID`, then create a `telegram-inbox` automation with `use_skill` enabled. It polls Telegram, accepts messages only from the owner chat ID, and replies through the configured bot.

## Automations

Create an automation from the web app or ask your agent to do it. It runs a prompt on a cron schedule with the selected model and thinking level. An automation without `bot_id` is a workspace automation; set `bot_id` to make it a bot automation that runs with the bot's identity. `use_skill` runs the skill whose name matches `job_name`; its optional `scripts/preScript.ts` output is added to the agent context. After Pi completes, optional `scripts/postScript.ts` runs for follow-up work; a failing script fails the automation. `daily_session` reuses one Pi session per day, `can_overlap` permits concurrent runs, and `monitor` shows the job in the web app. Use `/automations` in Pi to inspect scheduled jobs.

## Contribute

Install Node dependencies and run the package checks:

```bash
npm install
npm run check
npm run lint
npm test
```

For the web app, install Elixir/Erlang and run:

```bash
cd web-app
mix setup
MIX_ENV=test mix precommit
```

Build a production web release with `cd web-app && bin/deploy`. Set `SECRET_KEY_BASE`, `PHX_HOST`, and `WORKSPACE` before starting it with `MIX_ENV=prod mix phx.server`.
