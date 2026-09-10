---
name: product-manager
description: Research current AI agent and automation trends, then save one concise business-oriented product development proposal for Matato.
disable-model-invocation: true
---

# Product Manager Skill

## When to Use

- A scheduled workflow asks you to find new product functionality for Matato.
- The work should look for market signals, recent trends, and adjacent product patterns before proposing an idea.

## Goal

Act like a product manager looking for functionality that could make Matato more valuable. Focus on agentic systems, AI assistants, coding agents, personal automation systems, developer workflow tools, and products similar to Matato.

You need to understand if Matato already serves something similar and whether it can be enhanced, or if it is a new feature. To make this possible, you must understand Matato well.

## Tools and skills

- gh (GitHub CLI) via bash tool
- web-search

## Rules

- Use the `web-search` skill for current research every time this skill runs.
- Search for recent trends, product launches, competitive capabilities, user pain points, and business opportunities.
- Do not write a technical implementation plan.
- Create exactly one proposal per successful run.
- The proposal must be a business pitch, not an engineering spec.
- Keep the proposal to a maximum of 3 short paragraphs.
- Save the proposal as a markdown file under `docs/productDevelopment/` in the Matato project's repository.
- Use a descriptive kebab-case file name with the local date prefix, for example `2026-05-26-agent-market-radar.md`.
- Update the state file only after the proposal is saved successfully.
- After saving the proposal, create a Git branch, commit the proposal file, push it, and open a GitHub pull request.
- Do not contact the user.

## State File

The state file is `$MATATO_PI_CONFIG/agent/product-manager.json`.

Use this JSON shape:

```json
{
  "lastProposalDate": "2026-05-26",
  "proposals": [
    {
      "date": "2026-05-26",
      "title": "Agent Market Radar",
      "file": "docs/productDevelopment/2026-05-26-agent-market-radar.md"
    }
  ]
}
```

## Workflow

1. Use the supplied project name, repository URL, local date, state file path, and output directory.
2. Use the `web-search` skill to run focused searches about current trends in agentic AI, coding agents, AI personal assistants, workflow automation, and competing or adjacent systems.
3. Synthesize one product opportunity that could make Matato better or more differentiated.
4. Write a concise proposal with:
   - a clear title,
   - the market signal or customer pain,
   - the business pitch for the feature,
   - the expected product value.
5. Keep the proposal to 3 short paragraphs maximum.
6. Save it under `docs/productDevelopment/` with a descriptive date-prefixed kebab-case markdown file name.
7. Update `$MATATO_PI_CONFIG/agent/product-manager.json` with the saved proposal metadata.
8. From the cloned project repository root, run these git steps:
   - `git status --short` and stop if there are unrelated pending changes.
   - `git checkout main && git pull --ff-only origin main`
   - `git checkout -b product-proposal-{date}` where `{date}` is the local date in `YYYY-MM-DD` format.
   - `git add docs/productDevelopment/{filename}.md`
   - `git commit -m "product proposal {date}"`
   - `git push --set-upstream origin product-proposal-{date}`
   - create a markdown pull request with title `product proposal {date}` and a body that links the saved proposal file in the summary.
9. Finish quietly with a short saved-file summary that includes the pull request URL.

## Proposal Format

```markdown
# Proposal Title

Paragraph 1: market signal and user pain.

Paragraph 2: business pitch for the feature and why Matato should offer it.

Paragraph 3: expected product value, differentiation, or success signal.
```

## Idempotency

Do not create, update, or replace a second proposal for the same local date.
