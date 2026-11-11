# Agent guide

## Project scope

Matato Skills is a Pi package with skills and two extensions. It does not contain a standalone worker or the Matato web server.

## Package structure

| Path | Responsibility |
| --- | --- |
| `skills/<name>/SKILL.md` | Skill instructions and frontmatter. Some skills require explicit invocation. |
| `skills/<name>/scripts/` | Skill helpers for browser testing and web search. |
| `extensions/subagents/index.ts` | Fresh-context Pi tasks, single or concurrent batches of up to 16. |
| `extensions/remoteSession/index.ts` | `/remote` registration with an external server, with optional SSH/SCP transfer. |
| `src/cli.ts` | Shared flag parsing for skill helpers. |
| `src/discord.ts`, `src/telegram.ts` | Outbound messaging helpers; not registered Pi extensions. |

## Local commands and safety

Run these commands from the package checkout:

```bash
npm ci
pi install "$PWD"
npm run check
npm run lint
npm test
```

Use mocked command runners instead of live credentials or repositories in tests.

Subagents share a checkout unless given another directory. They do not create worktrees. Keep code-editing tasks isolated as required by their skills.

## Change checks

Keep changes scoped to the request. Add tests beside changed behavior using `*.test.ts` and Bun's test runner. Check affected callers and skill instructions when changing package behavior. Run `npm run check`, `npm run lint`, and `npm test`; report failures and skipped checks.

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

