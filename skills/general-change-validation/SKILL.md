---
name: general-change-review
description: Perform an independent change review as an explicit specialist used by $change-gate.
disable-model-invocation: true
---

# General Change Review

Review the code for the following categories You MUST change the code for any of them that doesn't pass the check. It means fix tests, fix linting errors, refactor, add missing tests, add logging, etc. Do not stop until all categories are in a good state.

## Strong types

Review for the usage of strong types, try to avoid weak types like `unknown`, `any` or such kind of types in the programming language the code is in.

## Safe guards

Always prefer safe guards at the start of a function that discard the edge cases and do early return instead of complex if-else statements or nested logic.

## YAGNI

Follow YAGNI principle and prefer one-line solutions when they are readable.

## Logging and monitoring

Analyse the code does log the right log levels depending the situation, if the project support monitoring via metrics, traces or anything other tool, make sure the code follows the standards in the repository.
