---
name: web-search
description: Use the bundled web-search scripts for fast factual lookups and current-information answers when deep research is not needed.
---

# Web Search Skill

## When to Use

- User asks for quick factual information.
- User asks for recent updates, trends, or links.
- User asks a narrow question that can be answered from a few web sources.
- User asks for a short comparison that does not require a full research report.

## Inputs

- query: string
- depthMode: quick|think|deep (default quick)
- maxResults: number (default 5, max 12)

## Runtime

- Run commands from this skill directory.
- Search uses SearXNG at `http://127.0.0.1:8888` by default; no API key is needed.
- Set `SEARXNG_URL` to override the endpoint. From another Tailscale device, use `http://leon.tail3cac52.ts.net:8888` (or `http://100.89.9.39:8888`). This service is tailnet-only, not public.
- Docker setup and Tailscale commands are in `extras/searxng/setup.md` in the Matato repository. The instance must enable the JSON search format.
- Use `bun scripts/searchWeb.ts --query "focused query" --depthMode quick --maxResults 5` for search results.
- Use `bun scripts/fetchPageContent.ts --url "https://example.com"` when full page content is needed from a specific result. This fetches the URL directly and returns raw HTML or text, not Tavily-style extracted article text; it does not execute JavaScript.
- Non-empty search responses are cached on disk for five minutes, keyed by endpoint and query, to reduce upstream requests across CLI invocations. Cache location: `${XDG_CACHE_HOME:-~/.cache}/matato/webSearch`; delete it to force fresh results or remove stored snippets. Errors and empty responses are not cached.
- Results contain SearXNG snippets in `content`; `rawContent` is empty. `depthMode` caps results at 4/8/12 for quick/think/deep, rather than selecting a provider search-depth mode.
- Do not rely on project source code, project package scripts, or project dependencies.

## Constraints

- Prefer the bundled search script first for lightweight requests.
- Do not trigger deep research for simple lookups.
- If the user requests a full report, synthesis, strategy document, comparison across many sources, or a broad investigation, route the work to `deep-research`.
- Do not fabricate facts when no evidence is returned.
- Keep answer concise unless user asks for depth.

## Steps

1. Convert user request into a focused `query`.
2. Choose `depthMode`:
   - `quick` for direct factual checks.
   - `think` for moderate comparison or ambiguity.
   - `deep` only when still staying in web-search flow and more context is needed.
3. Run `bun scripts/searchWeb.ts --query "focused query" --depthMode quick --maxResults 5` from this skill directory.
4. Parse returned JSON results and extract only evidence-backed points.
5. Fetch page content only when snippets are insufficient.
6. Respond with:
   - direct answer first,
   - brief evidence summary,
   - key links when relevant.
7. If results are insufficient or conflicting and user intent is investigative, route the work to `deep-research`.
