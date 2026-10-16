---
name: architecture
description: Review proposed or implemented changes for fit with the project's architecture. Use before coding or during review.
---

# Architecture review

1. Read project instructions and the task or diff to identify the change's scope.
2. Inspect related source and callers. Identify the existing architecture from actual dependencies and responsibilities, not folder names alone.
3. Check that the change follows that architecture: correct ownership, dependency direction, existing extension points, and preserved contracts.
4. If no architecture is visible, recommend **entrypoint → service → repository**: entrypoints handle input and output, services own business logic, and repositories handle data access. Dependencies point in that direction. Do not force unrelated code into these layers or require new directories or classes.
5. Report whether the change fits. For each mismatch, cite `path:line`, explain the impact, and suggest the smallest correction and a regression check. State evidence gaps instead of guessing. If no issues exist, say so.

Review only unless the user requests implementation. Do not redesign unrelated code.
