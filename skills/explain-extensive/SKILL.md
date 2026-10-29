---
name: explain-extensive
description: Run $explain-extensive when the user wants to review and understand a PR, a change, or existing code.
disable-model-invocation: true
---

# Explain Extensive

Scan the full code in scope, whether it is a PR, a change, or existing code, and use the `$deep-dive` and `$why` skills as companions to fully understand it.

Identify all relevant components, such as files, folders, modules, and tests, including added, updated, or deleted components when explaining a change. Build an incremental understanding that helps the user visualize the behavior, its impact, and how it fits into the codebase. Launch as many subagents as you need to get all the information needed.

## Categorization

Categorize the code in scope into these three types:

- **Entry points**: All entry points to the applications, such as APIs, endpoints, CLI commands, message handling, etc.
- **Domain layer**: All domain components that entry points connect to, to understand the business behavior and impact.
- **Outputs**: All output parts, such as database schemas, calls to an external service, messages sent, etc., and how the domain layer connects to those points.

## Output

Divide the output into the following parts:

1. Explain each category with one Mermaid diagram. Enumerate the steps to explain the sequence of events. Complement each diagram with an explanation of the internals.
2. Explain the relevant components and their purpose. For new components, justify their addition.
3. Provide a file structure diagram. For a PR or change, mark files as ADDED, MODIFIED, or DELETED where applicable.
4. If applicable, present a before-and-after diagram with Mermaid to help the user understand the old and new behavior.
