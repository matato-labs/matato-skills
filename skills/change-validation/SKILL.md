---
name: change-validation
description: Run $change-validation after a repository change to coordinate isolated acceptance, mutation, quality, and validation checks.
disable-model-invocation: true
---

# Change Validation

When invoked, use the supplied pull-request and repository data. The user will execute this skill in the target repository or provide you with a PR. You can find the repository under $WORKSPACE (env var). Confirm that the repository exists.

If you were given a PR, add the label `in-validation`, if the label does not exist, create it and add it to the PR. Remove the label `ai-validation`, YOU MUST DELETE THE `ai-validation` LABEL.

You MUST create a worktree under `/tmp` to isolate yourself from other agents running and work in that worktree. Run the following specialists in order, launching each as a fresh-context subagent. Give each subagent only the stable inputs and its own task, never prior subagent conversations or conclusions. Each subagent will have its own skill with instructions on what to do; each subagent must fix all the findings. They must return concise evidence, changes, and a summary.

1. Invoke `$acceptance-criteria-validation` for the supplied acceptance criteria.
2. Invoke `$general-change-validation` for an independent validation of the change.
3. Invoke `$mutation-testing-validation` for mutation-test evaluation.
4. Invoke `$quality-checks-validation` for project quality checks.
5. Invoke `$testing-quality` for in-code testing.

After all four subagents return, produce one gate report that preserves each specialist's verdict and evidence. The gate controller must not modify the repository, but specialists may make the controlled temporary mutations or test improvements required by their own skill.

If you were given a PR, commit and push with `gh`, add the label `human-review`, if the label do not exist, create it and then add it to the PR, then delete the label `in-validation`. When no pull request exists, just answer back with a quick summary.
