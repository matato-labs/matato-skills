---
name: change-gate
description: Run $change-gate after a repository change to coordinate isolated acceptance, mutation, quality, and review checks. Do not use for implementing changes.
disable-model-invocation: true
---

# Change Gate

When invoked by automation, first read the pre-script output in the prompt. If it contains `"skip": true`, stop quietly. Otherwise use its pull-request and repository data. The user will execute this skill in the target repository or it will provide you with a PR, you can find the repository under $WORKSPACE (env var). Confirm that the repository exit, then derive a change summary from the diff.

If you were given a PR, add the label `in-review`, if the label do not exist create it and add it to the PR. Remove the label `ai-review`, YOU MUST DELETE THE `ai-review` LABEL.

Run the following specialists in order, launching each as a fresh-context subagent. Give each subagent only the stable inputs and its own task, never prior subagent conversations or conclusions. Each subagent will have its own skill with instructions on what to do; some will modify the code, while others will only analyze it. They must return a concise evidence, and findings with file paths where applicable.

1. Invoke `$acceptance-criteria-review` for the supplied acceptance criteria.
2. Invoke `$general-change-review` for an independent review of the change.
3. Invoke `$mutation-testing-review` for mutation-test evaluation.
4. Invoke `$quality-checks-review` for project quality checks.

After all four subagents return, produce one gate report that preserves each specialist's verdict and evidence. The gate controller must not modify the repository, but specialists may make the controlled temporary mutations or test improvements required by their own skill.

## Last Step

If you were given a PR, commit and push with `gh`, add the label `human-review`, if the label do not exist, create it and then add it to the PR, then delete the label `in-review`. When no pull request exists, just answer back with a quick summary.
