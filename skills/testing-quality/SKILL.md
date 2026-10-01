---
name: testing-quiality
description: Run $testing-quiality when a change is done and you want ot make sure the tests are meaningful
disable-model-invocation: true
---

## Testing

The user will provide you with a change, local changes, a PR, a branch, etc, you task is to analyse them and make sure the changes are meaningful test.

- A good test verifies primarily the logic from from the business logic side follow the 3 steps of given/when/then. The assertions are on the state of the system, and preferable E2E or following the frameworks underused best practices.
- A good suite of tests is at different levels, we have unit tests with mock and stubs to check the internal logic of a file. Integration tests cover the module E2E workflows. API tests uses frameworks internal tooling to test the APIs with an E2E setup.
- Test as composable by layers, we have `Fixtures` to create runtime objects, models, entities, etc, define input by default but the option to override, scenarios are easy to create from the business side, I have utility files that helps to build the scenario with methods and functions that create the require data.
- Everything is tested, but we don't assert twice, we, a test is as good as it's assertions.

