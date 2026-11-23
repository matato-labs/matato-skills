---
name: audit
description: Audit a repository or package for bugs, safety and data risks, load failures, test gaps, and code or dependencies to remove. Use for read-only repository or subsystem audits, not individual change reviews.
---

# Audit

Audit the named scope, or the whole repo if none is named. Report findings; do not edit the code.

## Map the system before judging it

Read the entry points, build and deploy configuration, dependency declarations, and representative tests. Trace the highest-risk flows from a real entry point through state changes, failure handling, and the result. At each shared operation, check the other entry points that can produce the same user-visible failure. Check how the app is used before judging load, concurrency, or performance. On a large repo, go deep on flows where failure costs most and name the parts you did not examine.

## Look for behavior that can break or code that can go

- Find wrong results, broken error paths, data loss, unsafe trust boundaries, and failure at the expected load. For decisions that claim success, check what the code actually measures. Trace a normal negative case to see if incidental data can produce a false success even with valid input. For shared writes, check what happens when a legitimate action is repeated or arrives from another caller. Check where work or state can grow without a bound. Name the public outcome a missing test would protect.
- Check whether flags, wrappers, dependencies, and duplicate implementations serve a live need. Before calling something unused, search callers, tests, configuration, generated entry points, and dynamic references. Check language and framework conventions before treating their required structure as excess.
- At an input boundary, compare the consumer with the real producer and the documented formats. Check an ordinary input and a supported edge case. Transformed data need not match the source representation one-to-one.
- Prefer deleting code, using the existing path, or using a native feature or a dependency the project already has. Name what to keep and where it lives. Check semantics before suggesting consolidation; do not trade one copy for a new abstraction.

## Challenge and rank the findings

Keep a finding only if you can cite the code and trace a concrete failure or identify a verified removal. For each likely blocker, take one realistic trigger through every earlier guard: setup, validation, permissions, state and timing as applicable. Prefer a focused offline check at the real entry point. If you only checked an internal helper, do not claim the entry point can reach it without tracing the rest of the path.

Group symptoms with the same cause. For each fix, check a failing case and a working control against existing callers, fixtures, and contracts. Pick the control most likely to break: a different caller, a valid exceptional input, or the existing result limit. If two callers need different behavior, fix the caller with the problem. If you cannot support an implementation, state the behavior it must preserve instead of prescribing an unproven change.

Before reporting, make a second pass over the top findings. Check the actual caller and producer for ordering, limits, identity, and failure handling that the diagnosis or fix relies on. Record the exact probe and observed result if you ran one; distinguish that from a source trace. Rank by what the user loses: a wrong target, wrong saved state, or false success normally outranks lost display or continuity. Judge performance at a supported workload. Do not treat a documented trade-off as a defect unless real use crosses its limit.

Start with the system, scope, and load judged. Rank numbered findings: **Must fix** for broken behavior or material safety risk; **Should fix** for a concrete test, performance, or maintenance cost; **Nice to have** only for a verified small saving. For each, give the location, trigger, consequence, and smallest complete fix. Lead with what to fix first, omit empty groups, and stop at 20 findings. End with a verdict and what you could not check. Report verified removal opportunities without inventing line-count savings. If there are no findings, say what you checked.
