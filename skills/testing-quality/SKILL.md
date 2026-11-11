---
name: testing-quality
description: Check that a change has meaningful tests. Use when a change is complete or when reviewing test quality.
---

## Testing

Analyze the change that the user provides and check that it has meaningful tests. The user can provide local changes, a PR, a branch or another form of change.

- Verify code primarily through its business logic. Follow the 3 steps of given/when/then. Assert the system state, such as a function's return value or the data written to the database. Prefer E2E tests or the frameworks' underused best practices.
- Use tests at different levels. Use unit tests with mocks and stubs to check a file's internal logic. Use integration tests to cover the module's E2E workflows. Use the frameworks' internal tooling to test APIs with an E2E setup.
- Compose tests from layers. Use `Fixtures` to create runtime objects, models, entities and other required items. Define default input and allow overrides. Make business scenarios easy to create. Use utility files with methods and functions that create the data required for a scenario.
- Test everything, but do not duplicate assertions. Judge a test's quality by its assertions.
- Ask yourself, do I need to add this new test, is there a test that exist that I can expand the assestion, many times, is better to expand an existing test instead of creating a new one.
