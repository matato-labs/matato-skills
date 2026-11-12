---
name: testing-quality
description: Check that a change has meaningful tests. Use when a change is complete or when reviewing test quality.
---

## Testing

Analyze the change that the user provides and check that it has meaningful tests. The user can provide local changes, a PR, a branch or another form of change.

- Verify code primarily through its business logic and scenarios.
- Find the testing patterns in the projects and try to see reusable components, fixtures, test utilities
- Find the tests that already tests the code that change and find which existing tests can change to assert the new changes, prefer always expand existing tests with assertions instead of creating new tests. Ask yourself, do I need to add this new test, is there a test that exist that I can expand the assertion, many times, is better to expand an existing test instead of creating a new one.
- Follow the 3 steps of given/when/then.
- Compose tests from layers. Use `Fixtures` to create runtime objects, models, entities and other required items. Define default input and allow overrides. Make business scenarios easy to create. Use utility files with methods and functions that create the data required for a scenario.
