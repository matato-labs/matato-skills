# Matato Agent Web

Private Phoenix LiveView interface for `pi --mode rpc`. SQLite stores remote-session metadata and automations at `$MATATO_PI_CONFIG/matato-pi.sqlite3`; Pi JSONL sessions remain authoritative for conversation history.

## Run

```bash
cd web-app
WORKSPACE=/absolute/path/to/projects mix setup
WORKSPACE=/absolute/path/to/projects mix phx.server
```

Open `http://localhost:4000`. The picker lists direct child directories beneath `WORKSPACE` and rejects traversal and symlink escapes.

Optional configuration:

| Variable | Purpose |
| --- | --- |
| `MATATO_PI_CONFIG` | Matato data root. Stores `matato-pi.sqlite3`; defaults to `~/.config/matato-pi`. |
| `PI_CODING_AGENT_SESSION_DIR` | Optional Pi session directory. Defaults to `~/.pi/agent/sessions`. |
| `PORT` | HTTP port, default `4000`. |
| `OTEL_ENDPOINT` | Production-only OTLP/HTTP collector base URL. Defaults to `http://localhost:4318`; set it blank to disable trace and log export. |

Production binds to loopback by default. Put an authenticated TLS ingress or private tunnel in front. Pi is not sandboxed and runs with the web server user's host permissions.

## Database operations

Run `mix ecto.create` and `mix ecto.migrate` before the first production start. Back up and restore `matato-pi.sqlite3` as one SQLite database (including its WAL sidecars while the app is running). Pi JSONL and remote-session metadata are never imported.

## Production

Set `SECRET_KEY_BASE`, `PHX_HOST`, and `WORKSPACE` once in the production environment. Build a production deployment with:

```bash
bin/deploy
```

The script installs only production dependencies, compiles the application, and builds/digests assets. It never creates or changes secrets. Start the built application with:

```bash
MIX_ENV=prod mix phx.server
```

Automations and their skill scripts remove `MIX_ENV` inherited from the server, so Mix defaults to its `dev` environment rather than accessing the production database.

In production, when `OTEL_ENDPOINT` is configured, the web app exports Phoenix HTTP and LiveView traces to `/v1/traces` and application logs to `/v1/logs`, with the service name `matato-pi-web`. Telemetry export is disabled in development and tests. Pi extensions, skills, prompts, tool calls, and agent content are not instrumented.

## Supported flow

Start and resume durable sessions, stream assistant text and tool state, send normal prompts, steer, queue follow-ups, clear queues, abort, stop, and answer select, confirm, input, or editor extension requests. Browser reconnects hydrate completed history from Pi and receive the server's bounded warm-process snapshot.

## Checks

```bash
MIX_ENV=test mix precommit
```
