# Matato Pi Package

Install locally with:

```bash
pi install /absolute/path/to/matato-pi
```

The package provides Matato skills, prompts, the `subagent` extension from `../skills`, and archive browsers. It never imports `../matato` at runtime.

`/plans` browses Markdown files in `~/.config/matato-pi/plans/<git-root-name>/`; it requires a Git repository. `/researches` browses Markdown files in `~/.config/matato-pi/research/`. Both commands are read-only interactive two-pane viewers.

`/automations` manages scheduled jobs in `~/.config/matato-pi/automations/config.json`. Its `automations` entries use Matato's job fields: name, raw cron schedule, prompt, model, reasoning effort, enabled state, sub-agent permission, and an optional TypeScript pre-script filename.

Run `npm run worker` to start the standalone scheduler in `worker/`. It reloads that config every five seconds, resolves each skill from `~/.pi/agent/skills/` (or `skills/` in this package), runs its configured optional TypeScript pre-script from the skill's `scripts/` directory, and starts a one-shot `pi --mode rpc` run with the script output in the prompt. Pi stores sessions in its default session directory.

Run checks with `npm run check`, `bun test`, and `npm run lint`.
