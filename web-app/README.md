# Matato Agent Web

Private Phoenix LiveView interface for `pi --mode rpc`. It has no database. Pi JSONL sessions are authoritative; the app stores only remote-session mappings in an atomic JSON file.

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
| `MATATO_PI_CONFIG` | Matato automation config root. Defaults to `~/.config/matato-pi`; automations are read from `automations/config.json`. |
| `MATATO_PI_WEB_STORAGE` | Metadata and managed Pi session root. Defaults to `~/.config/matato-pi/web-app`. |
| `MATATO_WEB_USER` | HTTP Basic Auth user. Required in production. |
| `MATATO_WEB_PASSWORD` | HTTP Basic Auth password. Required in production. |
| `PORT` | HTTP port, default `4000`. |

Production binds to loopback by default. Put an authenticated TLS ingress or private tunnel in front. Pi is not sandboxed and runs with the web server user's host permissions.

## Supported flow

Start and resume durable sessions, stream assistant text and tool state, send normal prompts, steer, queue follow-ups, clear queues, abort, stop, and answer select, confirm, input, or editor extension requests. Browser reconnects hydrate completed history from Pi and receive the server's bounded warm-process snapshot.

## Checks

```bash
mix precommit
```
