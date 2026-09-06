---
name: quality-checks-review
description: Run quality checks as an explicit specialist used by $change-gate.
disable-model-invocation: true
---

# Quality Checks Review

Review the code for the following quality categories and fix all findings, do not stop until all categories are in a good state.

## File size

Files can be larger than 600 lines of code. If a file exceeds the limit, it means it is doing many things and testing becomes hard. Analyze the file and split it. When splitting, make sure you do not introduce coupling, affect other components, or introduce unnecessary complexity.

## Circular dependencies

Identify circular dependencies in the new code, and analyze the changes both ways: is this code calling a component that is already calling it? Is this code being called by a component that it is already calling? Refactor the code to remove all circular dependencies.

## Direct data access

Direct data access from interfaces such as message handling, endpoints, CLI command handlers, or any entry point is forgiven. Data access can only happen through its domain service. For example, an `OrderRepository` can only be read from the `OrderService`.

Cross-domain data access is also forgiven. For example, the `UserService` cannot access the `OrderRepository`; it has to go through `OrderService`.

Refactor the code to fix all those mistakes.

## Cyclomatic complexity

Find functions with high cyclomatic complexity—many conditional or branching paths—and refactor them into smaller, clearly named units while preserving behavior and tests.

## Output

When you are done, reply to the orchestrator agent with a small summary and the state of your work.
