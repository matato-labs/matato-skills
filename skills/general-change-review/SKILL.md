---
name: general-change-review
description: Perform an independent change review as an explicit specialist used by $change-gate.
disable-model-invocation: true
---

# General Change Review

Review the code for the following categories. You MUST change the code for any of them that doesn't pass the check. It means fix tests, fix linting errors, refactor, add missing tests, add logging, etc. Do not stop until all categories are in a good state.

## Strong types

Review for the usage of strong types, try to avoid weak types like `unknown`, `any` or such kind of types in the programming language the code is in. Type checks should be done via the programming language strong typing systems instead of checks such as `if(value === string)`.

## Safe guards

Always prefer safe guards at the start of a function that discard the edge cases and do early return instead of complex if-else statements or nested logic.

## YAGNI

Follow YAGNI principle and prefer one-line solutions when they are readable.

## Logging and monitoring

Analyse the code does log the right log levels depending the situation, if the project support monitoring via metrics, traces or anything other tool, make sure the code follows the standards in the repository.

## Testing

Make sure the test have a business meaning according to the change, avoid technicalities in the test names. There are times the test is analysing a non-functional criteria, in such case if fine to introduce technicalities in the test.

## Typechecks and lint

Typechecks, linting passes, the project compile/build, all tests passes.

## Architecture

Analyse the code for lean and straight architecture, it means, no complex back and for calls between components, no thigh coupling, only introduce new components when it's extremely necessary.
