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
- The scripts use `TAVILY_API_KEY` from the environment.
- To set it up, create a Tavily account at https://app.tavily.com, generate an API key, and persist it with `the Matato configuration command or your shell environment`.
- Use `bun searchWeb.ts --query "focused query" --depthMode quick --maxResults 5` for search results.
- Use `bun fetchPageContent.ts --url "https://example.com"` when full page content is needed from a specific result.
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
3. Run `bun searchWeb.ts --query "focused query" --depthMode quick --maxResults 5` from this skill directory.
4. Parse returned JSON results and extract only evidence-backed points.
5. Fetch page content only when snippets are insufficient.
6. Respond with:
   - direct answer first,
   - brief evidence summary,
   - key links when relevant.
7. If results are insufficient or conflicting and user intent is investigative, route the work to `deep-research`.
