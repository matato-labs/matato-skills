---
name: github-issues
description: Use this skill when the user wants to create a GitHub issue in a configured project.
---

# GitHub Issues Skill

## Workflow

1. Identify the requested project from the user's request.
2. Use the project's repository URL to determine `OWNER/REPO`.
3. Use the user's request to prepare a concise issue title and a Markdown issue body.
4. Before you create the issue, list existing issues to avoid duplicates.
5. If an existing issue clearly covers the request, do not create a duplicate.
6. Write the Markdown body to a temporary `.md` file.
7. If there is no duplicate, create the issue with `--body-file` and `-R OWNER/REPO`.
8. Return the link to the issue you created or the existing issue.

## GH Commands

Specify the repository in each command:

### List issues and read issue content

```bash
gh issue list -R OWNER/REPO
gh issue view "{id}" -R OWNER/REPO
```

### Create an issue and add Markdown content

```bash
cat <<'EOF' >/tmp/github-issue-body.md
{description}
EOF
gh issue create -R OWNER/REPO --title "{title}" --label "{label}" --body-file /tmp/github-issue-body.md
gh issue edit "{id}" -R OWNER/REPO --body-file /tmp/github-issue-body.md
```

Prefer this structure for the issue body:

```md
## Problem

Short description of the issue.

## Proposed Solution

- A concrete and to-the-point way to solve this issue.

## Acceptance Criteria

- List of acceptance criteria divided into functional requirements and non-functional requirements
```
