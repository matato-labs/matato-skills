# Matato Pi

Matato Pi is a [Pi](https://github.com/earendil-works/pi) package for coding workflows, change validation, subagents, scheduled automations, and direct Telegram/Discord messages.

Pi loads the bundled skills, extensions, and prompt templates from `package.json`. Skills guide the agent; extensions add tools and commands. A standalone Bun worker uses Croner to run Pi prompts or skills on a schedule from `config/config.json`.

## Install

With Pi installed, choose either source:

**GitHub**

```bash
pi install git:github.com/LeonFelipeCordero/matato-pi
```

**Local checkout**

```bash
git clone https://github.com/LeonFelipeCordero/matato-pi.git
cd matato-pi
npm ci
pi install "$PWD"
```

For an existing checkout, run `npm ci` and `pi install "$PWD"` from its root. Restart Pi or run `/reload` to load the package.

## Skills

Use `/skill:<name>` or ask the agent for the matching task. Each linked skill documents its requirements and workflow.

| Skill | Purpose |
| --- | --- |
| [acceptance-criteria-validation](skills/acceptance-criteria-validation/SKILL.md) | Verify a change against its acceptance criteria. |
| [agent-pr-comment-resolver](skills/agent-pr-comment-resolver/SKILL.md) | Resolve `AGENT:` feedback on PRs labelled `resolve-comments`. |
| [browser-testing](skills/browser-testing/SKILL.md) | Smoke-test user flows in local Brave with playwright-cli. |
| [change-validation](skills/change-validation/SKILL.md) | Coordinate independent change-validation checks. |
| [coding-session](skills/coding-session/SKILL.md) | Guide coding work in a target project. |
| [deep-dive](skills/deep-dive/SKILL.md) | Investigate precise codebase questions. |
| [discord](skills/discord/SKILL.md) | Send approved messages to allowlisted Discord channels. |
| [explain](skills/explain/SKILL.md) | Explain a topic in depth. |
| [general-change-validation](skills/general-change-validation/SKILL.md) | Independently review a change. |
| [github-issues](skills/github-issues/SKILL.md) | Create GitHub issues in configured projects. |
| [handoff](skills/handoff/SKILL.md) | Capture a compact session handoff. |
| [interactive-pr-comment-resolver](skills/interactive-pr-comment-resolver/SKILL.md) | Resolve PR comments interactively. |
| [internals](skills/internals/SKILL.md) | Manage Matato automations, workers, and channel setup. |
| [mutation-testing-validation](skills/mutation-testing-validation/SKILL.md) | Check test effectiveness through manual mutations. |
| [notion-cli](skills/notion-cli/SKILL.md) | Manage Notion content with the official `ntn` CLI. |
| [quality-checks-validation](skills/quality-checks-validation/SKILL.md) | Run a project's quality checks. |
| [short-term-memory](skills/short-term-memory/SKILL.md) | Inspect previous sessions and logs. |
| [telegram](skills/telegram/SKILL.md) | Send approved messages to the Telegram owner. |
| [testing-quality](skills/testing-quality/SKILL.md) | Assess whether tests are meaningful. |
| [web-search](skills/web-search/SKILL.md) | Look up current information; requires `TAVILY_API_KEY`. |
| [why](skills/why/SKILL.md) | Explain why code behaves or is designed a certain way. |

## Extensions

| Extension | Tool or command | Purpose |
| --- | --- | --- |
| [automations](extensions/automations/index.ts) | `/automations` | Inspect local automation jobs; scheduling requires the worker. |
| [discord](extensions/discord/index.ts) | `discord_send_message` | Send directly to allowlisted guild channels. |
| [remoteSession](extensions/remoteSession/index.ts) | `/remote [name] [--host <sshHost>]` | Register a persisted session with a running Matato server, optionally copying it over SSH. |
| [subagents](extensions/subagents/index.ts) | `subagent` | Run fresh-context Pi tasks and await results; up to four concurrently. |
| [telegram](extensions/telegram/index.ts) | `telegram_send_message` | Send directly to the configured owner. |

Telegram requires `TELEGRAM_BOT_TOKEN` and `TELEGRAM_OWNER_ID`. Discord requires `DISCORD_BOT_TOKEN`, `DISCORD_GUILD_ID`, and comma-separated `DISCORD_CHANNEL_IDS`. Set these in the sending Pi process; channels are outbound only.

## Contribute

Fork the repository, clone your fork, and create a branch for your change. Install Node.js and Bun, then run from the repository root:

```bash
npm ci
npm run check
npm run lint
npm test
```

Add skills in `skills/<name>/SKILL.md`, extensions in `extensions/<name>/index.ts`, and prompt templates in `prompts/`. Follow `AGENTS.md`, add tests for behavior changes, and update this README when adding a skill or extension.

Open a pull request against `main` with a short summary and the checks you ran. For larger changes, open an issue first to discuss the approach.

### Secret scanning

CI runs Gitleaks 8.30.1 against the complete checked-out branch history, including merge-commit changes, for every pull request and push to `main`. With the same version installed, run locally:

```bash
gitleaks git --log-opts="--full-history --diff-merges=first-parent HEAD" --redact=100 --ignore-gitleaks-allow --max-decode-depth=5 --max-archive-depth=3 --no-banner
```

`.gitleaksignore` accepts only exact audited historical findings: the development/test signing keys and a synthetic token fixture. It does not exclude their files or disable detection rules. New findings require review; never blanket-ignore a file or commit to make CI pass.

Keep real credentials in local environment or credential files, not tracked examples. Git ignores and deleting a file do not remove existing Git history. Rotate any real exposed credential before considering history cleanup.
