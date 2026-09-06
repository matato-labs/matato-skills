---
name: ticket-tdd-implementer
description: "Implement a specific user-provided ticket from local documentation, Jira, or a prompt that explicitly asks to use this skill, using a strict three-phase approval flow."
disable-model-invocation: true
---

# Ticket TDD Implementer

Follow this skill when implementing work from a user-provided ticket. The
source may be a local file, a folder the user points to, a Jira ticket
key/link, or a detailed prompt saying to use this skill. Drive
implementation through a strict three-phase approval workflow.

The three required phases are:

1. Plan phase: analyze the ticket, define scenarios, and present the
   implementation/test plan. Stop for user approval.
2. Test phase: write the tests only. Stop for user approval after the
   user reviews the tests.
3. Implementation phase: implement the behavior to satisfy the approved
   tests, then continue with explicit red/green/refactor loops when
   needed.

Do not skip, merge, or reorder these phases unless the user explicitly
asks for a different workflow.

## Required Input

Collect and confirm before editing code:

- Ticket source to implement (required). This must come from the user
  and may be one of:
  - a direct file path
  - a folder plus ticket reference, for example `docs/tickets` +
    `ticket 8`
  - a Jira key or Jira link
  - a detailed prompt that states the requirements
- Supporting documentation paths or references (required when needed to
  understand the ticket)
- Target repository/module location (required)
- Preferred test command (required)
- Any constraints that must not change (APIs, schemas, behavior)

Do not assume a default ticket folder. Use the user-provided source of
truth.

If the ticket source is missing, ask:

`Which ticket should I implement, and where should I read it from?`

## Ticket Discovery

Use the source the user provides:

- If the user gives a direct file path, read that file first
- If the user gives a folder and ticket reference, find the matching
  ticket file inside that folder
- If the user gives a Jira key or Jira link, use Jira as the primary
  source and read only the linked or referenced supporting docs that are
  necessary
- If the user provides both a local ticket doc and a Jira ticket,
  clarify which one is the source of truth when they disagree
- If the user provides a prompt, go back and forth with the user to
  extract as much information as needed to complete the task

Do not search broadly for tickets unless the user has already pointed
you to the folder or source.

Locate and read only files needed for the selected ticket:

- Ticket file or Jira issue matching the selected ticket reference
- Requirement sections referenced by that ticket
- Acceptance criteria, scenarios, dependencies, and constraints for that
  ticket

## Phase 1: Plan Approval

Before writing tests or code, analyze the ticket and summarize:

- What must be built now
- What is out of scope
- What behaviors the tests must describe
- What assumptions are required
- What existing files, modules, and test suites are the best fit

If the ticket already contains clear TDD scenarios, TDD expectations,
acceptance criteria, or equivalent testable behavior, use them directly.
If the user provides the test scenarios in the prompt, use them
directly.

If the ticket does not provide enough information to determine solid
test scenarios, derive a proposed scenario set from:

- the ticket intent
- domain behavior
- existing code patterns
- adjacent tests
- explicit product assumptions that you call out to the user

In this case, describe the proposed scenario behaviorally and highlight
assumptions and ambiguities.

Then present a concrete three-phase plan:

1. Plan approval summary
2. Test creation approach and where the tests will live
3. Implementation approach after tests are approved

Use this exact prompt at the end of Phase 1:

`Please review the proposed scenarios and implementation plan. What should I change before I write the tests?`

Do not write tests or implementation code until the user explicitly
approves the Phase 1 plan.

## Phase 2: Test Creation Approval

After the user approves Phase 1, create the tests only.

In this phase:

- Add TDD-style tests that encode the approved behavior
- Use scenario-oriented names when they fit the codebase style
- Place tests in the most natural existing domain, feature, or
  architectural suite
- Create a new test file only when no existing suite is a clear fit
- Add only the minimum skeleton or placeholders required to make the
  tests compile or run when the test framework requires it
- Do not implement the real production behavior in this phase

Test-writing rules:

- Cover happy path plus critical edge cases from the approved scenarios
- Keep each test traceable to approved acceptance behavior
- Prefer deterministic fixtures and mocks over external integrations
  unless the existing test style clearly expects otherwise
- Keep test naming focused on domain behavior, not ticket numbers or
  ticket titles
- Do not mention ticket identifiers or ticket titles in production
  names, test names, test descriptions, or TDD scenario text
- Express test names and descriptions in business language, user
  behavior, and acceptance criteria terms

Run the focused test command and report:

- Passed tests
- Failing tests
- Pending tests
- What each result teaches about scope or ambiguity

Use this exact prompt at the end of Phase 2:

`Please review the tests. What should I change in the tests before I continue to implementation?`

Do not implement production behavior until the user explicitly approves
the tests.

## Phase 3: Implementation

After the user approves the tests, implement the production behavior
that satisfies the approved tests.

In this phase:

- Replace placeholders with real behavior
- Keep the implementation aligned with the approved tests
- Extend tests only when new clarifications emerge and the user agrees
  the new coverage is needed
- Run the same focused tests, then broader relevant tests if needed

Implementation rules:

- Drive implementation from failing scenarios first
- Prefer user-visible outcomes and side effects over internal
  implementation-detail assertions
- Prefer real persistence in tests when that matches the surrounding
  test architecture
- Mock only true external boundaries when needed
- Keep names domain-oriented rather than ticket-oriented
- Do not include ticket numbers, ticket titles, Jira keys, or ticket
  shorthand in production code identifiers, user-facing strings, or
  inline implementation labels

## TDD Loop After Phase 3 Starts

Once implementation begins, continue with explicit red/green/refactor
loops as needed:

1. Red: identify the next failing approved scenario or failing
   assertion.
2. Green: implement the minimum behavior required to make it pass.
3. Refactor: improve structure, naming, and duplication without changing
   behavior.

When a new scenario appears during implementation that was not covered
in Phase 1 or Phase 2, stop and ask the user whether to add it before
expanding scope.

## Traceability Rules

- Keep ticket references out of production function names, production
  modules, test names, and TDD scenario text
- Keep ticket references out of test descriptions, example labels,
  fixture names, helper names, and placeholder names
- Do not create names like `getTicketEightDashboardData` or similar
  ticket-derived identifiers
- Use domain-oriented names that reflect the behavior or responsibility
  being implemented
- Describe behavior in terms of business rules, user outcomes, and
  acceptance criteria rather than ticket metadata
- Reference the ticket only in progress summaries, planning notes, or
  other non-code traceability contexts when needed

## Iteration Loop

Use this approval-gated loop:

1. Confirm the ticket source from the user
2. Analyze the ticket and derive scenarios if needed
3. Present the Phase 1 plan and get approval
4. Write tests only
5. Present the Phase 2 tests and get approval
6. Implement production behavior
7. Continue red/green/refactor as needed
8. Re-open approval if scope changes or new scenarios emerge

Repeat until the user is satisfied with both the tests and the
implementation.

## Completion Checklist

Complete only when all are true:

- Selected ticket reference is implemented
- Ticket source was explicitly provided by the user
- Phase 1 plan was approved before tests were written
- Phase 2 tests were approved before implementation began
- Any newly discovered scenario was approved before expanding scope
- Approved tests pass, or any remaining pending states are documented
  and approved
- Implementation matches ticket scope and constraints
- User confirms outcome or requests the next ticket
