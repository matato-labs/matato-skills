# Agent guide

## Project scope

Matato Pi is a Pi package with skills, two extensions, and a standalone Bun automation worker. It does not contain the Matato web server. Use [README.md](README.md) for installation, worker commands, automation fields, and the complete [skill](README.md#skills) and [extension](README.md#extensions) tables.

## Package structure

| Path | Responsibility |
| --- | --- |
| `skills/<name>/SKILL.md` | Skill instructions and frontmatter. Some skills require explicit invocation. |
| `skills/<name>/scripts/` | Skill helpers; the worker recognizes optional `preScript.ts` and `postScript.ts` hooks. |
| `extensions/subagents/index.ts` | Fresh-context Pi tasks, single or concurrent batches of up to 16. |
| `extensions/remoteSession/index.ts` | `/remote` registration with an external server, with optional SSH/SCP transfer. |
| `worker/index.ts` | Worker startup, logging, and shutdown. |
| `worker/scheduler.ts` | Cron schedules, unique job names, and same-job overlap control. |
| `worker/watcher.ts` | Config polling and schedule replacement. |
| `worker/runner.ts` | Skill lookup, hooks, Pi arguments, and daily session paths. |
| `worker/process.ts`, `worker/piOutput.ts` | Process-tree cancellation and Pi output handling. |
| `src/automation.ts`, `src/automationConfig.ts` | Automation types, config location, and loading defaults. |
| `src/workspaceRepos.ts` | Discovery of direct child repositories under `WORKSPACE` and command helpers. |
| `src/storagePath.ts` | Storage location, separate from the automation JSON path. |
| `src/discord.ts`, `src/telegram.ts` | Outbound messaging helpers; not registered Pi extensions or worker jobs. |
| `config/config.json` | Default worker automation definitions. |

```text
config/config.json -> watcher -> scheduler -> runner -> pi
                                               |-> skill preScript.ts
                                               |-> skill postScript.ts (after success)
```

## Local commands and safety

Run these commands from the package checkout:

```bash
npm ci
pi install "$PWD"
npm run check
npm run lint
npm test
```

Do not start `npm run worker` as a validation step. The bundled jobs are enabled every five minutes and can assign GitHub items, commit, push, and change PR labels. The worker launches Pi with `--approve`. Use mocked command runners and temporary config files in tests instead of live credentials or repositories.

For an intentional worker run, read the config first, confirm Pi credentials and the model, and set `WORKSPACE` for the bundled GitHub jobs. Authenticate `gh` and Git. Run `npm run worker` in the foreground; stop with `Ctrl+C` or `SIGTERM`.

## Automation rules

- Use `$MATATO_PI_AUTOMATIONS_CONFIG` when set; otherwise use `config/config.json` relative to this package. Do not edit the root `config.json` for worker changes. Do not use T3 scheduler tools to manage these jobs.
- Use the `matato-pi-automations` skill for job management. Preserve other jobs and fields. Keep `jobName` unique and new jobs disabled unless the user requests activation.
- Read `src/automation.ts` and `src/automationConfig.ts` before changing the schema or defaults. Croner accepts five- or six-field cron expressions in the worker's local time zone. Enabled `monitor` jobs are unsupported.
- `useSkill` defaults to true and `canOverlap` defaults to false. Set both explicitly in new examples. Skill jobs require `jobName` to match a skill directory.
- Skill lookup prefers `~/.pi/agent/skills/<jobName>` over the bundled skill. Hooks run from that skill directory; empty pre-script output skips Pi and the post-script. Pi itself inherits the worker's working directory.
- The worker polls about every five seconds. Invalid reloads retain existing schedules. Missing configs load an empty job list. Config edits neither start the worker nor cancel active runs.
- `MATATO_PI_CONFIG` controls storage, defaulting to `~/.config/matato-pi`; it does not select the automation JSON. Daily session files use its `sessions` directory.
- GitHub pre-scripts use direct child repositories of `WORKSPACE` with `origin` remotes. They select at most one item per run. Keep selection in pre-scripts and workflow instructions in the config's `userPrompt`.
- Subagents share a checkout unless given another directory. They do not create worktrees. Keep code-editing tasks isolated as required by their skills. `canLaunchSubAgents: false` disables the bundled extension, not all possible delegation tools.

## Change checks

Keep changes scoped to the request. Add tests beside changed behavior using `*.test.ts` and Bun's test runner. Check affected callers, config examples, and skill instructions when changing worker behavior. Run `npm run check`, `npm run lint`, and `npm test`; report failures and skipped checks.

When adding or removing a skill or extension, update the README inventory only when the user authorizes README changes. Keep skill-specific requirements in that skill's `SKILL.md`. Do not describe external tools or services as bundled components.

### General code rules

- Use guard clauses with early returns or throw errors instead of nested code

```ts
// DONT
if (a === b) {
  if (aFunction(a) === 'a value') {
    // some code...
  } else {
    console.log('a log')
  }
} else {
  console.log('another log')
}
// some other code code ...

// DO THIS  INSTEAD
if (a !== b) {
  console.log('a log')
}

const aValue = aFunction(a)
if (aValue !== 'a value') {
  console.log('a log')
}

// some code
// some other code code...
```

- Do not use Type[] to type an array, use `Array<Type>`
- Never use `unknown`, `any`, or imprecise placeholder types. Types must be precise. If the correct type cannot be resolved safely from the codebase or context, stop and ask the user for help instead of guessing.
- **DO NOT** do complex manual validations or duplicate TypeScript with runtime type checks. The TypeScript type system MUST be used over programmatic validations for input shapes and field types. If a value is typed as `string`, `number`, an object, or an array, do not add `typeof`, `Array.isArray`, `'property' in value`, or object-shape `if` checks to prove that again.
```ts
// DON'T
type RunJobInput = {
  jobName?: string
  timeoutSeconds?: number
}

const runJob = (input: RunJobInput): void => {
  if (typeof input.jobName !== 'string' || !input.jobName) {
    throw new Error('jobName is required')
  }

  if (typeof input.timeoutSeconds !== 'number') {
    throw new Error('timeoutSeconds is required')
  }

  startJob(input.jobName, input.timeoutSeconds)
}

// DO
type RunJobInput = {
  jobName: string
  timeoutSeconds: number
}

const runJob = (input: RunJobInput): void => {
  startJob(input.jobName, input.timeoutSeconds)
}
```

- **DO NOT** use `-` or `_` in names (functions, files, variables), follow the pattern `thisIsAName`

