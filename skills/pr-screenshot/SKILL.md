---
name: pr-screenshot
description: Capture browser evidence for a pull request and publish it in one pull-request comment.
disable-model-invocation: true
---

# Pull-request Screenshot Evidence

Identify the target pull request from a supplied URL or number. If none is supplied, use the pull request for the current branch with `gh pr view`; if that cannot identify one, stop.

Create an isolated worktree under `/tmp` at the pull request head and work only there. Inspect its diff and project scripts before testing. If the change has no runnable user-visible browser path, report that and stop.

Invoke `$browser-testing` to start the project and exercise the changed critical path. Keep its artifact directory until the evidence comment is created. Capture the smallest useful set of screenshots that demonstrates the change.

GitHub pull-request comments cannot upload local image files. Publish screenshots to a dedicated evidence branch without modifying the pull-request branch:

1. Create or reset `pr-screenshot-evidence/pr-<number>` from the pull request base branch in the isolated worktree.
2. Copy the selected screenshots into `pr-screenshots/pr-<number>/` with descriptive names, commit them, and push the evidence branch to `origin`.
3. Build raw GitHub URLs from the pushed evidence branch and use them as Markdown images.
4. Post exactly one `gh pr comment` containing every screenshot, its scenario, and its raw GitHub image URL. Do not create a comment per image.

If browser testing, publishing, or commenting fails, report the failure and preserve available artifacts. Always close the named browser session and stop the app process. Delete the browser artifact directory only after upload succeeds or when it is no longer needed.
