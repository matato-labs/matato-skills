# Matato Skills

A [Pi](https://github.com/earendil-works/pi) package for coding, code review, testing, and scheduled agent work. This repository includes skills, two extensions, and a standalone Bun worker. It does not include the Matato web server.

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

Restart Pi or run `/reload` after installation. Configure Pi provider credentials and confirm that your selected model works before you start scheduled work.

## Upgrade an existing installation

Reinstall this package from the URL above and remove its previous package entry. Update service definitions, shell settings, and external callers to use `MATATO_SKILLS_CONFIG`, `MATATO_SKILLS_AUTOMATIONS_CONFIG`, and `MATATO_SKILLS_WEB_URL`. Previous environment variable names are not supported.

Stop running processes before moving stored data. Move the previous storage directory to `~/.config/matato-skills`, or set `MATATO_SKILLS_CONFIG` to its existing location. Rename the database file there to `matato-skills.sqlite3` when present. Preserve session files and back up data first. This package does not migrate data automatically.

Update custom skill references and job names to `matato-skills-automations`, `matis-navigate`, and `matis-mutation-test`. Remove stale manually installed skill copies. External Matis installations, release artifacts, config files, and database paths must use the new names too; set `DATABASE_PATH` explicitly when retaining an existing database location.

## Skills

Use `/skill:<name>` to invoke a skill. Some skills require explicit invocation and do not load automatically. Read each linked skill for its requirements. Tools such as GitHub CLI, Matis, Notion CLI, and browser tooling are not installed by this package.

| Skill | What it does |
| --- | --- |
| [acceptance-criteria-validation](skills/acceptance-criteria-validation/SKILL.md) | Checks a change against acceptance criteria as a specialist for `change-validation`. |
| [agent-pr-comment-resolver](skills/agent-pr-comment-resolver/SKILL.md) | Resolves actionable `AGENT:` feedback on open PRs labelled `resolve-comments`. |
| [architecture](skills/architecture/SKILL.md) | Checks how a proposed or implemented change fits the codebase architecture. |
| [matis-mutation-test](skills/matis-mutation-test/SKILL.md) | Uses Matis mutation manifests to check whether tests detect realistic bugs. Requires Matis, Git, and the target project's test tools. |
| [matis-navigate](skills/matis-navigate/SKILL.md) | Uses an indexed Matis database to trace structure, symbols, callers, dependencies, and change impact. |
| [browser-testing](skills/browser-testing/SKILL.md) | Runs a focused local Brave smoke check with `playwright-cli` after a frontend or user-flow change. |
| [change-validation](skills/change-validation/SKILL.md) | Coordinates fresh-context specialists for acceptance criteria, independent validation, test quality, and mutation testing. |
| [coding-session](skills/coding-session/SKILL.md) | Implements a supplied issue or task in an isolated worktree under `/tmp`. |
| [deep-dive](skills/deep-dive/SKILL.md) | Investigates a precise question about how code works. |
| [explain](skills/explain/SKILL.md) | Explains a topic or system so the user can understand it. |
| [general-change-validation](skills/general-change-validation/SKILL.md) | Independently validates a change as a specialist for `change-validation`. |
| [github-issues](skills/github-issues/SKILL.md) | Checks for duplicate issues and creates a GitHub issue with `gh`. |
| [handoff](skills/handoff/SKILL.md) | Summarizes a session into a compact handoff for a new session. |
| [interactive-pr-comment-resolver](skills/interactive-pr-comment-resolver/SKILL.md) | Handles user-requested PR comment resolution. |
| [matato-skills-automations](skills/matato-skills-automations/SKILL.md) | Lists, creates, updates, pauses, and deletes worker jobs in the automation config. |
| [notion-cli](skills/notion-cli/SKILL.md) | Uses `ntn` to manage Notion pages, blocks, data sources, files, and Workers. |
| [short-term-memory](skills/short-term-memory/SKILL.md) | Searches previous sessions and external Matato web-app logs for recent activity. |
| [testing-quality](skills/testing-quality/SKILL.md) | Checks that a change has meaningful tests. |
| [web-search](skills/web-search/SKILL.md) | Searches the Brave Search API and fetches page content with Bun scripts. Requires `BRAVE_API_TOKEN`. |
| [why](skills/why/SKILL.md) | Investigates the reasons behind code behavior or design decisions. |

Some workflows reference external skills, such as `ponytail`, that are not bundled here. Install those separately when needed.

## Extensions

Pi loads these extensions when the package is installed.

| Extension | Interface | What it does |
| --- | --- | --- |
| [subagents](extensions/subagents/index.ts) | Agent tool: `subagent` | Runs one fresh-context Pi task or up to 16 independent tasks concurrently. Waits for all results. Inherits the active model and thinking level. Uses the caller's directory unless `cwd` is supplied; it does not create isolated worktrees. Nested subagents are disabled. |
| [remoteSession](extensions/remoteSession/index.ts) | `/remote [name] [--host <sshHost>]` | Registers a saved session with an existing Matato web server. With `--host`, copies the session by SSH/SCP before registration. Does not start a server. |

For `/remote`, set `WORKSPACE` to the parent directory of your projects. The current directory must be inside it, and the Pi session must be saved to a file. Without `--host`, the extension uses `MATATO_SKILLS_WEB_URL` or `http://localhost:4000`; the server must be able to access the session file. With `--host`, use an SSH config host name. The extension copies the file to `.pi/agent/sessions` on that host and registers it at `http://<sshHost>:4000`, regardless of `MATATO_SKILLS_WEB_URL`.

## Run the worker

The worker needs Bun and `pi` on `PATH`, installed dependencies, and Pi provider credentials. Run it from this checkout; jobs inherit the worker's working directory.

**Review the config before starting.** The three jobs in [`config/config.json`](config/config.json) are enabled, run every five minutes, and use `gpt-6-sol`. Their prompts can commit, push, create PRs, and change labels. Replace the model with one available in your Pi setup. The worker invokes Pi with `--approve`; run it only with trusted prompts, skills, and repositories.

```bash
# From the package checkout, after npm ci and pi install "$PWD":
export WORKSPACE="$HOME/workspace/projects"
gh auth status
npm run worker
```

`WORKSPACE` and authenticated `git`/`gh` access are needed for the bundled GitHub jobs, not for every custom prompt. `WORKSPACE` must contain repository directories as direct children, each with an `origin` remote.

The worker runs in the foreground and prints reload, completion, skip, and failure messages. It schedules jobs for their next cron time; it does not run every job on startup. Keep the process running for scheduled work. Stop it with `Ctrl+C` or `SIGTERM`; shutdown stops schedules and terminates active job processes. Installation and config edits do not start the worker.

To use a separate config:

```bash
MATATO_SKILLS_AUTOMATIONS_CONFIG=/absolute/path/automations.json npm run worker
```

Use an absolute path to avoid working-directory ambiguity. The default is the package's `config/config.json`, **not** the root `config.json`. The worker checks for changes about every five seconds. If a reload fails, it logs the error and retains the previous schedules. A missing file loads no jobs.

### Configure an automation

Use `/skill:matato-skills-automations` in Pi, or edit the selected JSON file. The top-level object contains an `automations` array. This example is disabled and runs a plain prompt when enabled:

```json
{
  "automations": [
    {
      "jobName": "dailySummary",
      "enabled": false,
      "schedule": "0 9 * * 1-5",
      "userPrompt": "Summarize the repository status. Do not change files.",
      "dailySession": false,
      "canOverlap": false,
      "model": "REPLACE_WITH_YOUR_PI_MODEL",
      "thinkingLevel": "medium",
      "canLaunchSubAgents": false,
      "useSkill": false
    }
  ]
}
```

Choose a valid model, adjust the prompt and schedule, then set `enabled: true` when ready. Append a job to an existing array instead of replacing other jobs. Validate JSON, cron expressions, and unique names before saving.

| Field | Meaning |
| --- | --- |
| `jobName` | Unique job name. With `useSkill: true`, it must match the skill directory name. |
| `enabled` | Whether the worker schedules this job. Set `false` to pause future runs. |
| `schedule` | Croner expression with five fields, or six fields including seconds. Uses the worker's local time zone. `0 9 * * 1-5` means weekdays at 09:00. |
| `userPrompt` | Prompt passed to Pi, or extra instructions for the selected skill. |
| `dailySession` | Optional; when true, passes a session ID of `<jobName>-YYYY-MM-DD` and a session directory under worker storage. Defaults to false. |
| `canOverlap` | Allows simultaneous runs of the same job. Defaults to false; overlapping ticks are skipped, not queued. Different jobs can still run concurrently. |
| `model` | Model identifier accepted by Pi's `--model` option. |
| `thinkingLevel` | `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, or `max`. Choose a level supported by your model. |
| `canLaunchSubAgents` | Allows the bundled `subagent` tool when true. When false, the worker sets `PI_SUBAGENT_DEPTH=1` to disable that extension. This is not a security sandbox. |
| `useSkill` | Runs `/skill:<jobName>` when true, or a plain prompt when false. Defaults to true if omitted. Set it explicitly. |
| `monitor` | Optional legacy field. Omit it or set false. The standalone worker rejects enabled monitor jobs. |

With `useSkill: true`, the worker looks first in `~/.pi/agent/skills/<jobName>`, then in this package's `skills/<jobName>`. It loads only that skill into the job's Pi invocation. If present, `scripts/preScript.ts` runs with Bun from the skill directory. Its output is appended to the prompt; empty output skips the job. After a successful Pi run, `scripts/postScript.ts` runs if present.

Daily session storage defaults to `~/.config/matato-skills/sessions`. Set `MATATO_SKILLS_CONFIG` to change the storage directory. This variable does **not** select the automation JSON file; use `MATATO_SKILLS_AUTOMATIONS_CONFIG` for that.

### Bundled GitHub jobs

Each pre-script scans direct child repositories of `WORKSPACE`, selects at most one matching item, assigns it to the authenticated GitHub user, and supplies its data to the skill. No matching item means the job is skipped.

| Job | Selection | Configured action |
| --- | --- | --- |
| `coding-session` | Open, unassigned issue labelled `AI`. | Implements the issue in a `/tmp` worktree, commits and pushes, then creates a PR labelled `ai-validation`. |
| `change-validation` | Open, unassigned PR labelled `ai-validation`. | Uses a `/tmp` worktree and specialist subagents. The prompt moves labels from `ai-validation` to `in-validation`, then to `human-review` after validation. |
| `agent-pr-comment-resolver` | Open PR labelled `resolve-comments`. | Runs the skill to resolve actionable feedback prefixed with `AGENT:`. |

The label transitions, commit, and push instructions are configured in `userPrompt`, not enforced by the scheduler. The validation selector requires an unassigned PR; remove an assignee if you want that job to select it.

## Development

```bash
npm run check
npm run lint
npm test
```

| Path | Purpose |
| --- | --- |
| `skills/` | Skill instructions and optional scripts. |
| `extensions/` | Pi extensions and their tests. |
| `worker/` | Scheduling, config polling, Pi execution, and process management. |
| `src/` | Shared automation types, config loading, storage paths, repository discovery, and messaging helpers. |
| `config/config.json` | Default standalone-worker automation config. |

Follow [AGENTS.md](AGENTS.md). Add tests for behavior changes, and keep the skill and extension tables current when their inventory changes.
