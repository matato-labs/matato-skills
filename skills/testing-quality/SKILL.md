---
name: testing-quality
description: Run $testing-quality when a change is done and you want to make sure the tests are meaningful
disable-model-invocation: true
---

## Testing

The user will provide you with a change, local changes, a PR, a branch, etc.; your task is to analyse them and make sure the changes have meaningful tests.

- A good test verifies primarily the logic from the business logic side and follows the 3 steps of given/when/then. The assertions are on the state of the system, and tests are preferably E2E or follow the frameworks' underused best practices.
- A good suite of tests has different levels: we have unit tests with mocks and stubs to check the internal logic of a file. Integration tests cover the module's E2E workflows. API tests use frameworks' internal tooling to test the APIs with an E2E setup.
- Tests are composable by layers. We have `Fixtures` to create runtime objects, models, entities, etc., and define input by default with the option to override. Scenarios are easy to create from the business side. I have utility files that help to build the scenario with methods and functions that create the required data.
- Everything is tested, but we don't assert twice. A test is as good as its assertions.

