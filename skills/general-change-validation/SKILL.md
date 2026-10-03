---
name: general-change-validation
description: Perform an independent change validation as an explicit specialist used by $change-validation.
disable-model-invocation: true
---

# General Change Validation

Validate the code for the following categories. You MUST change the code for any of them that doesn't pass the check. It means fix tests, fix linting errors, refactor, add missing tests, add logging, etc. Do not stop until all categories are in a good state.

## Strong types

Validate the usage of strong types, try to avoid weak types like `unknown`, `any` or such kind of types in the programming language the code is in. Type checks should be done via the programming language strong typing systems instead of checks such as `if(value === string)`.

## Safeguards

Always prefer safeguards at the start of a function that discard edge cases and return early instead of using complex if-else statements or nested logic.

## YAGNI

Follow the YAGNI principle and prefer one-line solutions when they are readable.

## Logging and monitoring

Analyse whether the code logs the right log levels depending on the situation; if the project supports monitoring via metrics, traces, or any other tools, make sure the code follows the standards in the repository.

## Typechecks and lint

Typechecks and linting pass, the project compiles/builds, and all tests pass.

## Architecture

Analyse the code for a lean and straightforward architecture, which means no complex back-and-forth calls between components and no tight coupling; only introduce new components when it's extremely necessary.
