# Matato Skills

A [Pi](https://github.com/earendil-works/pi) package for coding, code review, testing, and code investigation. This repository includes 19 skills and two extensions. It does not include a standalone worker or the Matato web server.

## Install

With Pi installed:

```bash
pi install git:github.com/LeonFelipeCordero/matato-skills
```

For local development, install Node.js, npm, Bun, and Pi, then run:

```bash
git clone https://github.com/LeonFelipeCordero/matato-skills.git
cd matato-skills
npm ci
pi install "$PWD"
```

Restart Pi or run `/reload` after installation. Configure Pi provider credentials and select a working model before using subagents.

## Skills

Use `/skill:<name>` to invoke a skill. Skills marked **Explicit** have `disable-model-invocation: true` and require explicit invocation. Read each linked skill for its full requirements and workflow.

| Skill | Invocation | What it does |
| --- | --- | --- |
| [acceptance-criteria-validation](skills/acceptance-criteria-validation/SKILL.md) | Explicit | Checks acceptance criteria and fixes gaps as a specialist for `change-validation`. |
| [agent-pr-comment-resolver](skills/agent-pr-comment-resolver/SKILL.md) | Explicit | Resolves actionable `AGENT:` feedback on supplied open PRs labelled `resolve-comments`. Uses a `/tmp` worktree, commits, and pushes changes. |
| [architecture](skills/architecture/SKILL.md) | Automatic or explicit | Checks how a proposed or implemented change fits the codebase architecture. |
| [break-me](skills/break-me/SKILL.md) | Explicit | Uses subagents to find realistic failure cases, then assigns subagents to fix findings. |
| [browser-testing](skills/browser-testing/SKILL.md) | Automatic or explicit | Runs a focused local Brave smoke check with the bundled Bun runner and `playwright-cli`. Collects snapshots, a screenshot, console output, and HTTP evidence. |
| [change-validation](skills/change-validation/SKILL.md) | Explicit | Uses a `/tmp` worktree and sequential fresh-context specialists for acceptance criteria, independent validation, test quality, architecture, and manual mutation testing. |
| [cli](skills/cli/SKILL.md) | Automatic or explicit | Describes the Projects, Research, and Plans databases and template rules in the Personal Work Notion workspace. It is not a bundled Notion CLI. |
| [deep-dive](skills/deep-dive/SKILL.md) | Explicit | Investigates a precise question about code through subagents and reports evidence. |
| [explain](skills/explain/SKILL.md) | Explicit | Explains a topic with `deep-dive`, `why`, evidence, and workflow diagrams. |
| [explain-extensive](skills/explain-extensive/SKILL.md) | Explicit | Explains a PR, change, or existing code through entry points, domain behavior, outputs, and diagrams. |
| [general-change-review](skills/general-change-validation/SKILL.md) | Explicit | Independently checks a change and fixes findings as a specialist for `change-validation`. |
| [handoff](skills/handoff/SKILL.md) | Explicit | Summarizes a session into a compact handoff for a new session. |
| [interactive-pr-comment-resolver](skills/interactive-pr-comment-resolver/SKILL.md) | Explicit | Reviews PR comments one at a time with the user and waits for approval before applying changes. |
| [mutation-testing-validation](skills/mutation-testing-validation/SKILL.md) | Explicit | Applies and restores one manual mutation at a time, checks whether tests detect it, and improves tests for surviving mutations. |
| [quality-checks-review](skills/quality-check-validation/SKILL.md) | Explicit | Reviews and fixes circular dependencies, complexity, and responsibility or dependency concentration. |
| [testing-quality](skills/testing-quality/SKILL.md) | Automatic or explicit | Checks that a change has meaningful scenario-based tests and reuses existing test patterns. |
| [verify-me](skills/verify-me/SKILL.md) | Automatic or explicit | Uses subagents to verify only the requested behavior and collect evidence. |
| [web-search](skills/web-search/SKILL.md) | Automatic or explicit | Searches the Brave Search API and fetches page content with Bun scripts. Requires `BRAVE_API_TOKEN` for search. |
| [why](skills/why/SKILL.md) | Explicit | Investigates the reasons behind code behavior or design decisions. |

Two skill directories differ from their declared names: `general-change-validation` declares `general-change-review`, and `quality-check-validation` declares `quality-checks-review`. Invoke them with `/skill:general-change-review` and `/skill:quality-checks-review`. Some validation instructions still reference directory names or `change-gate`, which is not bundled here.

Tools and services such as GitHub CLI, Git, Notion, Brave, and `playwright-cli` are not installed by this package. Browser testing requires Bun, global `playwright-cli`, and `/usr/bin/brave`. Some workflows reference external skills, such as `ponytail` and `deep-research`; install those separately when needed.

## Extensions

Pi loads these extensions when the package is installed.

| Extension | Interface | What it does |
| --- | --- | --- |
| [subagents](extensions/subagents/index.ts) | Agent tool: `subagent` | Runs one fresh-context Pi task or up to 16 independent tasks concurrently. Waits for results and inherits the active model and thinking level. |
| [remoteSession](extensions/remoteSession/index.ts) | `/remote [name] [--host <sshHost>]` | Registers a saved session with an external Matato web server. With `--host`, copies the session by SSH/SCP before registration. Does not start a server. |

### Subagents

Use `prompt` for one task or `tasks` for a concurrent batch. Each task accepts an optional `cwd`; relative paths resolve from the caller's directory. Start a prompt with `/skill:<name>` to delegate to a skill.

```json
{
  "tasks": [
    { "prompt": "Inspect the API tests. Do not edit files." },
    { "prompt": "Inspect the database tests. Do not edit files." }
  ]
}
```

Subagents do not receive the parent conversation, save Pi sessions, or create worktrees. They share the caller's checkout unless given another directory. Isolate concurrent editing tasks yourself. Nested subagents are disabled through `PI_SUBAGENT_DEPTH`; skills that need their own subagents cannot use this tool for nested delegation.

### Remote sessions

Set `WORKSPACE` to the parent directory of your projects. The current directory must be inside it, and the Pi session must be saved to a file. The session name defaults to the current directory's base name.

```bash
export WORKSPACE="$HOME/workspace/projects"
export MATATO_SKILLS_WEB_URL="http://localhost:4000"
```

In Pi:

```text
/remote
/remote API investigation
/remote API investigation --host piServer
```

Without `--host`, the extension uses `MATATO_SKILLS_WEB_URL` or `http://localhost:4000`; the server must be able to access the session file. With `--host`, use an SSH config host name. The extension copies the file to `~/.pi/agent/sessions` on that host and registers it at `http://<sshHost>:4000`, regardless of `MATATO_SKILLS_WEB_URL`. The HTTP host must also be reachable from the local machine. Registration reports a link to the remote session.

## Development

Run these commands from the package checkout:

```bash
npm run check
npm run lint
npm test
```

| Path | Purpose |
| --- | --- |
| `skills/<name>/SKILL.md` | Skill frontmatter and workflow instructions. |
| `skills/browser-testing/scripts/` | Browser runner, scenario handling, CLI parsing, and tests. |
| `skills/web-search/scripts/` | Brave search, page fetching, CLI parsing, and tests. |
| `extensions/subagents/` | Fresh-context Pi task tool and tests. |
| `extensions/remoteSession/` | Remote session registration, SSH/SCP transfer, and tests. |

Follow [AGENTS.md](AGENTS.md). Add tests for behavior changes, and keep the skill and extension tables current when their inventory changes.
