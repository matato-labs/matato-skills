# Private SearXNG

SearXNG runs in Docker, bound only to `127.0.0.1:8888`. Tailscale Serve forwards port `8888` privately to the tailnet. No Funnel, public listener, or API key is needed. HTTP over Tailscale is encrypted by the tailnet tunnel.

## Install on this computer

From the repository root, copy the configuration to a persistent directory so the service does not depend on a PR worktree:

```sh
mkdir -p ~/.local/share/matato/searxng
cp extras/searxng/compose.yaml extras/searxng/settings.yml ~/.local/share/matato/searxng/
cd ~/.local/share/matato/searxng
# Generate once; keep this secret out of Git.
(umask 077; printf 'SEARXNG_SECRET=%s\n' "$(openssl rand -hex 32)" > .env)
docker compose up -d
tailscale serve --bg --http=8888 --yes http://127.0.0.1:8888
```

The image is pinned by digest. Docker must start at boot; run `sudo systemctl enable docker.service` if it is not enabled. This requires host administrator access. `restart: unless-stopped` then restores the container. Tailscale's background Serve configuration persists. The rate limiter is disabled for this private instance, so no Redis/Valkey service is required. Only devices allowed by tailnet policy can access it; do not expose this configuration publicly.

## Use and verify

On this computer, the web-search skill defaults to `http://127.0.0.1:8888`. On other Tailscale devices, set:

```sh
export SEARXNG_URL=http://leon.tail3cac52.ts.net:8888
```

The IP endpoint is `http://100.89.9.39:8888`. Adjust the hostname/IP when installing on a different computer.

```sh
curl --fail 'http://127.0.0.1:8888/search?q=SearXNG&format=json'
curl --fail 'http://leon.tail3cac52.ts.net:8888/search?q=SearXNG&format=json'
docker compose --project-directory ~/.local/share/matato/searxng ps
tailscale serve status
```

Brave web search is disabled because it repeatedly returned HTTP 429 on this instance. Autocomplete is disabled to avoid extra upstream requests. Engine failures back off for 60–600 seconds; access-denied and rate-limit responses suspend engines for 15 minutes, and CAPTCHAs for two hours. Engine-specific suspension overrides still apply (the pinned DuckDuckGo engine uses zero seconds for its CAPTCHA response). Other default engines remain available; this reduces failures, not guarantees against upstream blocks.

The web-search script caches non-empty responses for five minutes under `${XDG_CACHE_HOME:-~/.cache}/matato/webSearch`, keyed by endpoint and query. Repeated queries reuse results across result limits and depth modes, including separate CLI invocations. Cached snippets and URLs remain on disk after expiry; delete that directory to remove them. Errors and empty responses are not cached.

To apply repository configuration changes to an existing installation:

```sh
cp extras/searxng/settings.yml ~/.local/share/matato/searxng/settings.yml
docker compose --project-directory ~/.local/share/matato/searxng up -d --force-recreate
```

Search engines can independently fail or rate-limit requests; inspect the response's `unresponsive_engines` field if results are sparse. The skill uses search snippets and fetches page HTML directly when requested; SearXNG is not an article extraction service.

## Stop

```sh
tailscale serve --http=8888 off
docker compose --project-directory ~/.local/share/matato/searxng down
```

These commands affect only SearXNG, not other Docker containers or Tailscale services.
