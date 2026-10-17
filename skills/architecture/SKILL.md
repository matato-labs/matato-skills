---
name: architecture
description: Use this skill to analyse the architecture of a codebase for a review, proposed or implemention.
---

# Architecture fit

Give some change in the local repository, a PR or just an idea, this skill a playbook to align everything to the project's architecture. . But some times that's not clear or the architecture is driven by an opinionated framework.

## Architecture finding

**Straight forward architecture**: Some projects will have a clear architecture, being layer architecture, onion architecture, clean architecture, hexagonal architecture. Identify the one the project follows.

**Opinionated framework**: Frameworks like phoenix, django, ruby on rail, are opinionated on how things are supposed to be be architect, in such cases where the underlying technology dictates the architecture, follows the standards you find in code or you know according the running version.

**Unclear architecture**: There will be cases where the architecture is not clear, for this case, default to a layer architecture oriented by features and following the classic `entry-point->Service->Repository`

## No goes

Independently of the architecture, there are things are not acceptable:

* Direct data access from entry points.
* Unclear ownership.
* Bidirectional calls.

## Analysis

With the architecture you found, do a deep analysis of the code or proposal under analysis and rate how well it fits in the current architecture. Extract all places where it diverges from the common patterns in the project and list them. Give all findings in the answer.
