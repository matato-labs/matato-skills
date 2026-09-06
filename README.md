# Matato Pi Package

Install locally with:

```bash
pi install /absolute/path/to/matato-pi
```

The package provides Matato skills, prompts, the `subagent` extension from `../skills`, and archive browsers. It never imports `../matato` at runtime.

`/plans` browses Markdown files in `~/.config/matato-pi/plans/<git-root-name>/`; it requires a Git repository. `/researches` browses Markdown files in `~/.config/matato-pi/research/`. Both commands are read-only interactive two-pane viewers.

Run checks with `npm run check`, `bun test`, and `npm run lint`.
