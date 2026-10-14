# Private Firecrawl

Firecrawl runs locally in Docker, bound only to `127.0.0.1:8888`. Tailscale Serve forwards that port privately to the tailnet. No Funnel, public listener, or API key is needed. The API has authentication disabled: keep it on loopback/trusted tailnet devices only.

## Install on this computer

From the repository root, copy the configuration to a persistent directory so the service does not depend on a PR worktree:

```sh
mkdir -p ~/.local/share/matato/firecrawl
cp extras/firecrawl/compose.yaml ~/.local/share/matato/firecrawl/
cd ~/.local/share/matato/firecrawl
git clone --depth 1 --branch v2.11.0 https://github.com/firecrawl/firecrawl.git source
# Pin the source used to build API, Playwright, and NuQ PostgreSQL.
git -C source checkout ef12eb36b2f3382838dfe0a0c1a5add3d5df7fe5
# Generate once; keep this secret out of Git.
(umask 077; printf 'POSTGRES_PASSWORD=%s\n' "$(openssl rand -hex 32)" > .env)
docker compose build
```

The stack includes API/workers, Playwright, Redis, RabbitMQ, and NuQ PostgreSQL; only the API publishes a host port. PostgreSQL data lives in a named volume. Redis/RabbitMQ queues are ephemeral; this setup is for on-demand search/scrape, not durable crawl jobs. No AI provider or paid Fire-engine is configured.

If replacing the existing SearXNG service, free its port after the build succeeds:

```sh
docker compose --project-directory ~/.local/share/matato/searxng down
```

Then start Firecrawl:

```sh
cd ~/.local/share/matato/firecrawl
docker compose up -d
tailscale serve --bg --http=8888 --yes http://127.0.0.1:8888
```

Docker must start at boot (`sudo systemctl enable docker.service` if needed). `restart: unless-stopped` restores the services. Background Tailscale Serve configuration persists. Other containers and Tailscale listeners are unaffected.

## Use and verify

The web-search skill defaults to the local endpoint. On another Tailscale device:

```sh
export FIRECRAWL_URL=http://leon.tail3cac52.ts.net:8888
```

The IP endpoint is `http://100.89.9.39:8888`. Adjust these addresses for another host. Supply the base URL without `/v2`.

Hermes has its own provider settings, separate from the Matato skill. On this computer:

```sh
hermes config set web.search_backend firecrawl
hermes config set web.extract_backend firecrawl
hermes config set FIRECRAWL_API_URL http://127.0.0.1:8888
```

Use the tailnet URL instead when Hermes runs on another device. Restart an already-running Hermes session/gateway to load the new environment.

```sh
curl --fail http://127.0.0.1:8888/v2/search \
  -H 'Content-Type: application/json' \
  -d '{"query":"Firecrawl documentation","limit":3,"sources":["web"]}'
curl --fail http://127.0.0.1:8888/v2/scrape \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://example.com","formats":["markdown"]}'
docker compose --project-directory ~/.local/share/matato/firecrawl ps
tailscale serve status
```

Self-hosted Firecrawl uses DuckDuckGo when neither SearXNG nor paid Fire-engine is configured. It does **not** include the hosted service's proprietary anti-bot infrastructure. Search engines and target sites can still block/rate-limit requests; upstream search failures can return `success: true` with no web results. Inspect API logs if results are empty. Scraping uses basic HTTP fetch and Playwright and returns Markdown, not raw HTML.

## Stop

```sh
tailscale serve --http=8888 off
docker compose --project-directory ~/.local/share/matato/firecrawl down
```

This keeps the PostgreSQL volume. Do not add `--volumes` unless you intend to delete its data.
