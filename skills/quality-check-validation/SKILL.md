---
name: quality-checks-validation
description: Run quality checks as an explicit specialist used by $change-gate.
disable-model-invocation: true
---

# Quality Checks Review

Review the code for the following quality categories and fix all findings, do not stop until all categories are in a good state.

## Circular dependencies

Identify circular dependencies in the new code, and analyze the changes both ways: is this code calling a component that is already calling it? Is this code being called by a component that it is already calling? Refactor the code to remove all circular dependencies.

## Cyclomatic complexity

Find functions with high cyclomatic complexity—many conditional or branching paths—and refactor them into smaller, clearly named units while preserving behavior and tests.

## Fan IN/OUT

God files are a bad pattern, a file can't have multiple resposabilities and dependencies and a file can't be dependency for many other. This is only possitive for utilit classes, fixtures and domain models.

## Output

When you are done, reply to the orchestrator agent with a small summary and the state of your work.
