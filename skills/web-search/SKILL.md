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
- Search and page extraction use self-hosted Firecrawl at `http://127.0.0.1:8888` by default; no API key is needed.
- Set `FIRECRAWL_URL` to override the base URL (without `/v2`). From another Tailscale device, use `http://leon.tail3cac52.ts.net:8888` (or `http://100.89.9.39:8888`). This service is tailnet-only, not public.
- Docker setup and Tailscale commands are in `extras/firecrawl/setup.md` in the Matato repository.
- Use `bun scripts/searchWeb.ts --query "focused query" --depthMode quick --maxResults 5` for search results.
- Use `bun scripts/fetchPageContent.ts --url "https://example.com"` when full page content is needed from a specific result. This calls Firecrawl's `/v2/scrape` endpoint and returns extracted Markdown, with Playwright available for JavaScript pages.
- Search calls `/v2/search` and returns web snippets in `content`; `rawContent` is empty and no relevance score is supplied. `depthMode` caps results at 4/8/12 for quick/think/deep, rather than selecting a provider search-depth mode.
- Self-hosted search uses DuckDuckGo, not Firecrawl's hosted anti-bot infrastructure. CAPTCHAs/rate limits can still produce empty results; do not treat an empty response as evidence that no sources exist.
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
