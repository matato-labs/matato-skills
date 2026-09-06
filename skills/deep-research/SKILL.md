---
name: deep-research
description: Use this skill when the user wants a broad investigation, deep research report, lifecycle-managed saved research, or a synthesized comparison backed by multiple sources.
---

# Deep Research Skill

## When to Use

Use this skill when the user is not asking for a quick lookup but for a real investigation that should become a saved research artifact.

That usually means broad research, deep research, report writing, synthesis across multiple sources, strategy research, competitor or tool comparison, or open-ended investigation.

If the user only needs a direct fact, fresh link, or short answer from a few sources, use `web-search` instead.

## Goal

Gather evidence first, synthesize second, and save the final research in the `researches` lifecycle store only after the report is complete. The final reply must help the user immediately and include a GUI link to the saved research.

## Related skills

- web-search

## Research workflow

Use the `web-search` skill for all evidence gathering. Search as deeply as needed for the user's request and keep searching until the gathered evidence satisfices the request. Do not stop after one search, one source, or one viewpoint when the request asks for investigation.

Break broad topics into smaller angles, run searches for each angle, compare sources, and inspect contradictions. Prefer authoritative, primary, recent, or technically specific sources when available. Keep uncertainty explicit when evidence is thin, conflicting, or time-sensitive.

Only save the research after all data has been gathered and synthesized. Do not create a draft row at the beginning. Do not save generated research under `data/agent/` or as loose Markdown files.

## Research document shape

Save the Markdown artifact with this shape:

```markdown
# Title

- Scope: ...
- Depth: quick | normal | deep | exhaustive
- Timestamp: 2026-07-04T14:30:00+02:00

## Synthesized findings

Short research synthesis written from multiple sources.

## Key evidence

Important evidence, agreements, contradictions, and why the sources matter.

## Tradeoffs and uncertainty

Important caveats, disagreements, missing evidence, or open questions.

## Sources

- [Source name](https://example.com)
- [Source name](https://example.com)
```

## CRUD operations

Use the research CLI for lifecycle operations:

Create a completed research:

```bash
matato --json research create --title "Research title" --depth deep --markdown-file /tmp/research.md --sources-file /tmp/sources.md
```

Read one research:

```bash
matato --json research read <researchId>
```

List researches:

```bash
matato --json research list
```

Update a research:

```bash
matato --json research update <researchId> --title "New title" --markdown-file /tmp/research.md --sources-file /tmp/sources.md
```

Delete a research:

```bash
matato --json research delete <researchId>
```

Use `--markdown-file -` or `--sources-file -` to read from stdin when helpful. The sources file is a Markdown list of links:

```markdown
- [Source title](https://example.com)
- [Another source](https://example.org)
```

Depth should be `quick`, `normal`, `deep`, or `exhaustive`, matching how much investigation was needed.

## Final response

After creating the research, answer the user directly with a compact summary, key findings when helpful, source links, and the GUI link `/researches/<researchId>`. Do not dump raw search output. Synthesize it.
