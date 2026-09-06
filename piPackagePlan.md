# Matato Pi Package Plan

## Scope

`../matato-pi` is a Pi Package containing Matato skills, prompt templates, and one subagent extension. It does not contain identity/guardrail extensions, domain tools, commands, dashboards, a client adapter, or daemon integration.

```text
matato-pi/
├── extensions/subagents/index.ts
├── skills/<skill>/SKILL.md
├── prompts/
├── themes/
└── package.json
```

## Package Standard

Use the `pi` manifest in `package.json` and install locally with:

```bash
pi install /absolute/path/to/matato-pi
```

Pi packages provide resources only. Telegram polling, scheduled jobs, queues, SQLite, RPC supervision, Phoenix, and the future `matatod` daemon remain outside this package.

## Skills

Copy 22 skills from `../matato/data/agent/skills/`, excluding its duplicate `web-search`, plus the canonical `web-search` from `../skills/`. Do not copy any skill from `../matato-skills/` or the other generic skills from `../skills/`.

Correct `second-step` and `third-step` frontmatter names. Preserve required helper scripts and tests. Copied skills must not import or fall back to `../matato` at runtime.

## Prompts

Provide `/plan`, `/research`, `/workReview`, and `/systemHealth` as optional user-facing shortcuts.

## Subagent Extension

Use `../skills/extensions/subagent.ts` as the implementation source. It registers `subagent`, launches an isolated Pi process only after explicit user delegation, propagates cancellation, prevents recursive delegation, limits output, stores full truncated output temporarily, and cleans it up at session shutdown.

Keep the implementation aligned with that source. The only compatibility adjustment is a fallback thinking level when Pi does not provide one.

## Verification

```bash
npm run check
bun test
npm run lint
pi -e /absolute/path/to/matato-pi --help
```

## Completion Criteria

- Pi discovers the manifest resources
- all 23 selected skills have valid unique names
- prompt templates expand
- the `subagent` tool behaves like `../skills/extensions/subagent.ts`
- no package file imports `../matato` or `../matato-skills` at runtime
