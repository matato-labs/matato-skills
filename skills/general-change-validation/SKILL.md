---
name: general-change-validation
description: Independently validate a change when $change-validation explicitly uses this specialist.
disable-model-invocation: true
---

# General Change Validation

Validate the code in the following categories. If a category fails its check, you must change the code to fix it. This can include fixing tests, fixing linting errors, refactoring, adding missing tests, or adding logging. Do not stop until all categories pass their checks.

## Strong types

Check that the code uses strong types. Try to avoid weak types such as `unknown`, `any`, or similar types in the programming language. Use the language's strong type system for type checks instead of checks such as `if(value === string)`.

## Safeguards

Always prefer safeguards at the start of a function. Use them to handle edge cases and return early instead of using complex if-else statements or nested logic.

## YAGNI

Follow the YAGNI principle and prefer one-line solutions when they are readable.

## Logging and monitoring

Check that the code uses the correct log level for each situation. If the project supports monitoring through metrics, traces, or other tools, check that the code follows the repository's standards.

## Typechecks and lint

Make sure typechecks and linting pass, the project compiles/builds, and all tests pass.

## Architecture

Check that the code has a simple architecture with no complex sequences of calls in both directions between components and no tight coupling. Introduce new components only when they are essential.
