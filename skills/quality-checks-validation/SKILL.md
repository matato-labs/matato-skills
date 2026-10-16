---
name: quality-checks-validation
description: Run quality checks when $change-validation explicitly uses this specialist.
disable-model-invocation: true
---

# Quality Checks Validation

Validate the code in the following quality categories. Fix all findings. Do not stop until all categories pass their checks.

## File size

Use a limit of 600 lines of code per file. A file that exceeds this limit has too many responsibilities and is difficult to test. Analyze the file and split it. When you split it, do not introduce coupling, affect other components, or introduce unnecessary complexity.

## Circular dependencies

Identify circular dependencies in the new code. Analyze the changes in both directions. Does this code call a component that already calls it? Does a component call this code when this code already calls that component? Refactor the code to remove all circular dependencies.

## Direct data access

Do not access data directly from interfaces such as message handlers, endpoints, CLI command handlers, or other entry points. Access data only through its domain service. For example, only the `OrderService` can read an `OrderRepository`.

Do not access another domain's data directly. For example, the `UserService` cannot access the `OrderRepository`. It must use `OrderService`.

Refactor the code to fix all these mistakes.

## Cyclomatic complexity

Find functions with high cyclomatic complexity: many conditional or branching paths. Refactor them into smaller units with clear names. Preserve behavior and tests.

## Output

When you finish, send the orchestrator agent a short summary and the status of your work.
