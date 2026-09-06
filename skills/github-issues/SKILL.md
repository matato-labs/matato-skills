---
name: github-issues
description: Use this skill when the user wants to create a GitHub issue in a configured project.
---

# GitHub Issues Skill

## Workflow

1. Identify the requested project from the user request.
2. Derive `OWNER/REPO` from the project's repository URL.
3. Prepare a concise issue title and a Markdown issue body from the user request.
4. Before creating the issue, list existing issues to avoid duplicates.
5. If an existing issue clearly covers the request, do not create a duplicate.
6. Write the Markdown body to a temporary `.md` file.
7. If there is no duplicate, create the issue with `--body-file` and `-R OWNER/REPO`.
8. Return the created issue link or the existing one.

## GH Commands

Use repo-qualified commands:

### List Issues and read issue content
```bash
gh issue list -R OWNER/REPO
gh issue view "{id}" -R OWNER/REPO
```

### Create and add markdown content to issue
```bash
cat <<'EOF' >/tmp/github-issue-body.md
{description}
EOF
gh issue create -R OWNER/REPO --title "{title}" --label "{label}" --body-file /tmp/github-issue-body.md
gh issue edit "{id}" -R OWNER/REPO --body-file /tmp/github-issue-body.md
```


Preferred body shape:

```md
## Problem

Short description of the issue.

## Proposed Solution

- Concreate and to the point way to solve this issue.

## Acceptance Criteria

- List of acceptance critirias divided in functional requirements and nun functional requirements
```

