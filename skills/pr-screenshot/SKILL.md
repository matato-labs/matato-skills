---
name: pr-screenshot
description: Capture browser evidence for an open pull request labeled AI review and publish it in one pull-request comment.
disable-model-invocation: true
---

# Pull-request Screenshot Evidence

The automation pre-script supplies one open pull request labeled `AI review`. Work only on that pull request and repository. If no context was supplied, stop without making changes.

Create an isolated worktree under `/tmp` at the pull request head and work only there. Inspect the pull request diff and its project scripts before testing. If the change is no longer runnable or has no user-visible browser path, remove the `AI review` label and stop.

Invoke `$browser-testing` to start the project and exercise the changed critical path. Its artifact directory must remain available until the evidence comment has been created. Capture the smallest useful set of screenshots that demonstrates the change. Do not use port `4000`, which belongs to the automation web application.

GitHub pull-request comments cannot upload local image files. Publish screenshots to a dedicated evidence branch instead of modifying the pull-request branch:

1. Create or reset `ai-review-evidence/pr-<number>` from the pull request base branch in the isolated worktree.
2. Copy the selected screenshots into `ai-review/pr-<number>/` with descriptive names, commit them, and push the evidence branch to `origin`.
3. Build raw GitHub URLs from the pushed evidence branch and use them as Markdown images.
4. Post exactly one `gh pr comment` containing every screenshot, its scenario, and its raw GitHub image URL. Do not create a comment per image.

Only after the evidence branch push and single comment both succeed, remove the `AI review` label with `gh pr edit <number> --remove-label "AI review"`. If browser testing, publishing, or commenting fails, leave the label in place so a later automation run can retry. Always close the named browser session, stop the app process, and delete the browser artifact directory after the upload step.
