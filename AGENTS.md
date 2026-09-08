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

