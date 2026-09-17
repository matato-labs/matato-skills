# Matato Pi web app

Set `WEB_APP_TIME_ZONE` to configure the application's time zone. It defaults to `Europe/Berlin`.

```bash
WEB_APP_TIME_ZONE=America/New_York mix phx.server
```

## LiveDashboard

The app ships a Phoenix LiveDashboard with Phoenix, LiveView, Ecto/SQLite, and
VM metrics.

In development, open `http://localhost:4000/dev/dashboard`. Outside development
the dashboard is served at `/dashboard`. Destructive dashboard actions are
disabled. When serving the dashboard through a reverse proxy, make sure the
proxy terminates TLS and allows WebSocket upgrades for
`/dashboard/livewebsocket`, as LiveDashboard needs a LiveView socket
connection.
