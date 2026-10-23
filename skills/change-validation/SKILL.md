---
name: change-validation
description: Run $change-validation after a repository change to coordinate separate checks for acceptance criteria, mutation testing, quality, and validation.
disable-model-invocation: true
---

# Change Validation

When invoked, use the supplied pull-request and repository data. The user will run this skill in the target repository or provide a PR. Use the $WORKSPACE environment variable to locate the repository. Confirm that the repository exists.

You must create a worktree under `/tmp` to keep your work separate from other running agents. Work in that worktree. Run the following specialists in order. Start each specialist as a subagent with a fresh context. Give each subagent only the stable inputs and its own task. Do not give it conversations or conclusions from earlier subagents. Each subagent has its own skill with instructions. Each subagent must fix all findings. It must return concise evidence, its changes, and a summary.

1. Invoke `$acceptance-criteria-validation` for the supplied acceptance criteria.
2. Invoke `$general-change-validation` for an independent validation of the change.
3. Invoke `$testing-quality` for in-code testing.
4. Invoke `$architecture` for the overall architecture.
5. Invoke `$mutation-testing-validations` for mutation-test evaluation.

After all subagents return, produce one gate report that preserves each specialist's verdict and evidence. The gate controller must not modify the repository. Specialists may make the controlled temporary mutations or test improvements that their own skill requires.

When you finish, reply with a short summary.

