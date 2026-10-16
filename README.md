# Matato Pi

A [Pi](https://github.com/earendil-works/pi) package for coding, code review, testing, and scheduled agent work.

## Install

With Pi installed:

```bash
pi install git:github.com/LeonFelipeCordero/matato-pi
```

For local development, install Node.js and Bun, then run:

```bash
git clone https://github.com/LeonFelipeCordero/matato-pi.git
cd matato-pi
npm ci
pi install "$PWD"
```

Restart Pi or run `/reload` after installation.

## What it includes

Ask the agent for a task, or use `/skill:<name>`. Browse [all skills](skills/) for requirements and instructions.

- **Coding and review:** coding sessions, architecture checks, change validation, acceptance checks, and PR comment resolution.
- **Code understanding:** Atlas navigation, deep dives, explanations, and design rationale.
- **Testing:** browser smoke tests, test-quality reviews, and manual or Atlas-based mutation testing.
- **Other workflows:** GitHub issues, Notion, web search, session history, and handoffs. Web search requires `BRAVE_API_TOKEN`.
- **Subagents:** run independent Pi tasks in parallel and collect their results.
- **Remote sessions:** `/remote [name] [--host <sshHost>]` registers a saved session with an existing Matato server. The server is not included here; see the [extension](extensions/remoteSession/index.ts) for configuration.

## Scheduled automations

The standalone Bun worker runs Pi prompts or skills on cron schedules. Review the jobs and models in [`config/config.json`](config/config.json) before starting it; the bundled jobs are enabled.

```bash
npm run worker
```

Use `/skill:matato-pi-automations` to manage jobs. The worker reloads config changes automatically. Set `MATATO_PI_AUTOMATIONS_CONFIG` to use another config file. Editing the config does not start the worker.

## Development

```bash
npm run check
npm run lint
npm test
```

Add skills under `skills/` and extensions under `extensions/`. Follow [AGENTS.md](AGENTS.md) and add tests for behavior changes.
