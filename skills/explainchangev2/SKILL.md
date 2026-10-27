---
name: explainchangev2
description: Explain a diff, commit, or PR with small Mermaid diagrams and concise, source-grounded text for a visual learner. Invoke explicitly for a visual walkthrough.
disable-model-invocation: true
---

# Explain Change v2

Teach a mental model, not a file inventory. Show what changes, how it works, and why it matters.
Work read-only; do not install dependencies, run effectful commands, or change the project to explain it.

## Investigate
- Resolve the requested change and exact base/head; for local edits, state what the diff includes.
- Inspect the full diff, including deletions; do not trust a truncated API file list or PR summary.
- Group changes by behavior; read implementation, callers, old behavior, configuration, persistence, and test assertions.
- Privately map every changed area to an explained behavior or an explicit omission, including supporting changes.
- Trace a representative input to its observable result, then trace failure/recovery and authority changes.
- Separate source facts, inferred rationale, author claims, checks actually run, and unavailable evidence.
- For a large change, delegate independent subsystem reading when permitted and useful; reconcile findings against source.

## Explain in this order
1. **The change in one minute:** user-visible outcome, before → after, main tradeoff, and non-goals.
2. **The map:** one small Mermaid overview of responsibilities and named handoffs. Mark new/changed/unchanged.
3. **Follow one example:** carry the same concrete actor/input through the main path to a visible result.
4. **What else changes:** follow map order through materially different paths and supporting behavior clusters.
5. **When things go wrong:** one concrete interruption, what survives, what retries/blocks, and what the user sees.
6. **Using it safely:** rollout, compatibility, defaults, permissions, migrations/data, dependencies, and limitations.
7. **Remember:** the few causal facts that connect the design back to the user's problem; then evidence/gaps.

## Make diagrams teach
- Give each diagram one question; use a flowchart for structure/decisions, sequence for time, state for lifecycle.
- Aim for 4–7 nodes/participants. Split larger views at a named handoff; keep names stable across zoom levels.
- Define unfamiliar terms before using them; distinguish durable records, running processes, and external systems.
- Label arrows with actions/data. Structural arrows must not imply a synchronous call or execution order.
- Quote flowchart labels, use simple IDs and portable Mermaid, and never rely on color alone.
- Pair each diagram with a takeaway and a concrete example or short matching steps, not a prose arrow-by-arrow copy.
- Distinguish accepted/enqueued, executed/completed, and externally confirmed wherever they differ.
- Explain each queue/worker/boundary by the hazard it prevents, its scope, and its cost; avoid unsupported guarantees.
- Use before/after diagrams only when the visual contrast teaches more than a sentence.

## Scale detail, not noise
- Keep the overview readable on its own; add a reading route for long explanations.
- Zoom into each distinct behavior only as needed; complexity may require more sections, not a giant graph.
- Explain responsibilities and design reasons, not every helper; label inferred reasons as inference.
- Put secondary variants and a compact coverage note after the main story; disclose material omissions.
- Cover cross-cutting risks once. Skip mandatory directory trees, layer diagrams, repeated summaries, and praise.
- Keep concise text beside diagrams; move dense citations/check logs to an evidence section keyed by behavior.
- Do not cap the whole explanation at 60 lines: that limit applies to this skill, not the change being explained.

## Verify before returning
- Recheck arrows, ownership, ordering, defaults, failure states, and coverage against implementation and test assertions.
- Cite revision-specific repository links or path:line ranges for substantive claims; distinguish base from head.
- Test assertions show what is checked, not that tests passed; mocked boundaries do not establish live interoperability.
- Parse/render Mermaid with available tooling; disclose checks not performed without installing tools just for this task.
- Ask yourself: can the reader retell the outcome, trace an input, locate authority/state, and predict a failure?
- Repair missing causal links, unexplained jargon, repetition, and unsupported claims before returning.
