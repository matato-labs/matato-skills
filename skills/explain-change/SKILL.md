---
name: explain-change
description: Run $explain-change when the user wants to review and understand a change.
disable-model-invocation: true
---

# Explain Change

This requires you to scan a full change and use the `$deep-dive`, `$why`, and `$explain` skills as companions to fully understand the change. 

You need to identify all added/updated/deleted components, such as files, folders, modules, and tests, to build an incremental understanding of the change that helps the user visualize the impact and how it fits into the existing codebase. Launch as many subagents as you need to get all the information needed.

## Categorization

Categorize all changes into these three types:

- **Entry points**: All entry points to the applications, such as APIs, endpoints, CLI commands, message handling, etc.
- **Domain layer**: All changes in the domain layer that entry points connect to, to understand the business impact.
- **Outputs**: All output parts, such as database schema changes, calls to an external service, messages sent, etc., and how the domain layer connects to those points.

## Output

The output would be divide into the following parts:

1. Explain each of the categories with one mermaid diagram, enumarete the steps to explain the sequence of events. Complement each diagram with an explation of the internals.
2. Explain any new added components, justify it's addition.
3. Provide a file structure diagram with ADDED,MODIFIED,DELETED.
3. If applicable, present a before-and-after diagram with Mermaid to help the user understand the old and new behavior.
