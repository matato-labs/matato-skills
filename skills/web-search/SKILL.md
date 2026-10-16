---
name: web-search
description: Use the bundled web-search scripts to find facts quickly and answer questions about current information when deep research is not needed.
---

# Web Search Skill

## When to Use

- Use this skill when the user asks for quick factual information.
- Use this skill when the user asks for recent updates, trends, or links.
- Use this skill when the user asks a narrow question that a few web sources can answer.
- Use this skill when the user asks for a short comparison that does not require a full research report.

## Inputs

- Set `query` to a string.
- Set `depthMode` to `quick`, `think`, or `deep`. The default is `quick`.
- Set `maxResults` to a number. The default is 5. The maximum is 12.

## Runtime

- Run commands from this skill directory.
- Search uses the Brave Search API at `https://api.search.brave.com/res/v1/web/search`.
- Set `BRAVE_API_TOKEN` in the environment. The script fails before it searches if the token is missing or blank. It fails without a fallback if the API returns an error, including an invalid token error. You do not need a local search service.
- Use `bun scripts/searchWeb.ts --query "focused query" --depthMode quick --maxResults 5` for search results.
- Use `bun scripts/fetchPageContent.ts --url "https://example.com"` when you need full page content from a specific result. The script fetches the URL directly. It returns raw HTML or text, not article text extracted in the Tavily style. It does not execute JavaScript.
- The script caches non-empty search responses on disk for five minutes. It uses a hash of the token and request URL as the cache key. This reduces requests to the API across CLI invocations. The cache location is `${XDG_CACHE_HOME:-~/.cache}/matato/webSearch`. Delete the cache to force fresh results or remove stored snippets. The script does not cache errors or empty responses.
- Results contain Brave descriptions in `content`. The `rawContent` field is empty. The `score` field is the reciprocal of the result rank, not a relevance score from the provider. The `depthMode` field limits results to 4 for `quick`, 8 for `think`, and 12 for `deep`. It does not select a search-depth mode from the provider.
- Do not rely on project source code, project package scripts, or project dependencies.

## Constraints

- For simple requests, prefer the bundled search script as the first tool.
- Do not trigger deep research for simple lookups.
- Route the work to `deep-research` if the user requests a full report, synthesis, strategy document, comparison across many sources, or broad investigation.
- Do not fabricate facts when no evidence is returned.
- Keep the answer concise unless the user asks for detail.

## Steps

1. Convert the user's request into a focused `query`.
2. Choose `depthMode`:
   - Use `quick` for direct factual checks.
   - Use `think` for a moderate comparison or ambiguity.
   - Use `deep` only when you stay in the web-search workflow and need more context.
3. Run `bun scripts/searchWeb.ts --query "focused query" --depthMode quick --maxResults 5` from this skill directory.
4. Parse the returned JSON results. Extract only points that the evidence supports.
5. Fetch page content only when snippets are insufficient.
6. Structure the response as follows:
   - Give the direct answer first.
   - Give a brief summary of the evidence.
   - Include key links when relevant.
7. Route the work to `deep-research` if results are insufficient or conflicting and the user wants an investigation.
