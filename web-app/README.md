# Matato Pi web app

Set `WEB_APP_TIME_ZONE` to configure the application's time zone. It defaults to `Europe/Berlin`.

```bash
WEB_APP_TIME_ZONE=America/New_York mix phx.server
```

## LiveDashboard

The app ships a Phoenix LiveDashboard with Phoenix, LiveView, Ecto/SQLite, VM,
automation, and agent-session metrics.

In development, open `http://localhost:4000/dev/dashboard`. No credentials are
required there.

Outside development the dashboard is served at `/dashboard` and is protected by
HTTP basic authentication. Set both environment variables before starting the
app; without them the route responds with 404:

```bash
DASHBOARD_USERNAME=admin DASHBOARD_PASSWORD=secret mix phx.server
```

Credentials are read at runtime and must never be committed to the repository.
Destructive dashboard actions are disabled. When serving the dashboard through
a reverse proxy, make sure the proxy terminates TLS and allows WebSocket
upgrades for `/dashboard/livewebsocket`, as LiveDashboard needs a LiveView
socket connection.
