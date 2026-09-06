---
name: ghcli
description: Use this skill when the agent needs to use the GitHub CLI for issues, pull requests, comments, review threads, branches, or repository metadata.
---

# GitHub CLI

Use `gh` inside the target repository. Use `-R OWNER/REPO` only when not in the repo.

Core rules:
- Prefer `gh` over raw API calls. Use `gh api graphql` only when `gh` does not expose the data.
- Verify `--json` fields against the command help or by running `--json` with no field list. Do not request unsupported fields such as `reviewThreads` or `merged` from `gh pr view --json`.
- Use `--body-file` for multiline Markdown bodies.
- Use `--jq` for stable parsing; avoid table output.
- Make the smallest remote change; do not merge unless explicitly asked.
- Do not request changes on a PR you opened. If the PR author is `@me`, use `gh pr comment` instead of `gh pr review --request-changes`.

## Repo and auth

```bash
gh auth status
gh repo view --json nameWithOwner,url,defaultBranchRef
gh repo view OWNER/REPO --json nameWithOwner,url,defaultBranchRef
gh repo list OWNER --limit 50
```

## Issues

```bash
gh issue list --state open --limit 30
gh issue list --search "text in:title,body" --state all --limit 30
gh issue list --label bug --state open --json number,title,url,labels,assignees,updatedAt
gh issue view 218
gh issue view 218 --json number,title,body,state,author,labels,assignees,comments,url
gh issue view 218 --comments
gh issue view 218 --json comments --jq '.comments[] | {author: .author.login, createdAt, body}'
gh issue edit 218 --title "Updated title"
gh issue edit 218 --add-label bug --remove-label enhancement
gh issue edit 218 --add-assignee @me
gh issue edit 218 --body-file /tmp/issue-body.md
gh issue close 218 --comment "Closing because this was completed in #123."
gh issue reopen 218 --comment "Reopening because the problem still reproduces."
gh issue delete 218 --yes
gh issue comment 218 --body-file /tmp/issue-comment.md
gh issue comment 218 --edit-last --body-file /tmp/issue-comment.md
gh issue comment 218 --delete-last --yes
gh api repos/OWNER/REPO/issues/218/comments --jq '.[] | {id, user: .user.login, body}'
gh api repos/OWNER/REPO/issues/comments/COMMENT_ID --method PATCH -F body=@/tmp/issue-comment.md
gh api repos/OWNER/REPO/issues/comments/COMMENT_ID --method DELETE
```

## Pull requests

```bash
gh pr list --state open --limit 30
gh pr list --search "text in:title,body" --state all --limit 30
gh pr list --author @me --state open --json number,title,url,headRefName,baseRefName,reviewDecision,statusCheckRollup
gh pr view 123
gh pr view 123 --json number,title,body,state,author,url,headRefName,baseRefName,mergeStateStatus,reviewDecision,comments,reviews,files,commits,statusCheckRollup
gh pr view 123 --json state,mergedAt,mergeCommit
gh pr view 123 --json files --jq '.files[] | {path, additions, deletions}'
gh pr view 123 --json headRefOid --jq '.headRefOid'
```

### Supported `gh pr view --json` fields

The exact fields supported by `gh pr view --json` are:

```text
additions, assignees, author, autoMergeRequest, baseRefName, baseRefOid, body,
changedFiles, closed, closedAt, closingIssuesReferences, comments, commits,
createdAt, deletions, files, fullDatabaseId, headRefName, headRefOid,
headRepository, headRepositoryOwner, id, isCrossRepository, isDraft, labels,
latestReviews, maintainerCanModify, mergeCommit, mergeStateStatus, mergeable,
mergedAt, mergedBy, milestone, number, potentialMergeCommit, projectCards,
projectItems, reactionGroups, reviewDecision, reviewRequests, reviews, state,
statusCheckRollup, title, updatedAt, url
```

Do not request fields that are not in this list, such as `reviewThreads` or
`merged`, from `gh pr view --json`. Use GraphQL via `gh api graphql` when you
need data that `gh` does not expose.

```bash
gh pr diff 123
gh pr diff 123 --name-only
gh pr checks 123
gh pr checkout 123
gh pr checkout 123 --detach
gh pr create --base main --head featureBranch --title "Short PR title" --body-file /tmp/pr-body.md
gh pr edit 123 --title "Updated PR title"
gh pr edit 123 --base main
gh pr edit 123 --add-label enhancement --remove-label bug
gh pr edit 123 --add-assignee @me
gh pr edit 123 --body-file /tmp/pr-body.md
gh pr close 123 --comment "Closing because this approach is superseded."
gh pr reopen 123
gh pr merge 123 --squash --delete-branch
gh pr merge 123 --merge --delete-branch
gh pr merge 123 --rebase --delete-branch
```

## PR comments and reviews

```bash
gh pr view 123 --comments
gh pr view 123 --json comments,reviews --jq '{comments: .comments, reviews: .reviews}'
gh pr comment 123 --body-file /tmp/pr-comment.md
gh pr review 123 --comment --body-file /tmp/pr-review.md
gh pr review 123 --approve --body-file /tmp/pr-review.md
gh pr review 123 --request-changes --body-file /tmp/pr-review.md
```

> Do not use `--request-changes` on a PR opened by `@me`. GitHub rejects it. Use `gh pr comment` instead.

Post a line-level review comment through the REST API using a temporary JSON file and a local validation step. All required fields must be integers or strings exactly as shown.

```bash
cat <<'EOF' > /tmp/inline-comment.json
{
  "commit_id": "HEAD_SHA",
  "path": "src/file.ts",
  "line": 42,
  "position": 42,
  "side": "RIGHT",
  "subject_type": "line",
  "body": "Comment body in Markdown."
}
EOF

jq -e '
  (.commit_id | type == "string" and length > 0) and
  (.path | type == "string" and length > 0) and
  (.line | type == "number") and
  (.position | type == "number") and
  (.side | IN("LEFT", "RIGHT")) and
  (.subject_type == "line") and
  (.body | type == "string" and length > 0)
' /tmp/inline-comment.json >/dev/null

gh api repos/OWNER/REPO/pulls/123/comments \
  --method POST \
  --input /tmp/inline-comment.json
```

## PR review threads

> Warning: `diffSide` does not exist on `PullRequestReviewComment`. Do not request it in GraphQL or pass it to REST payloads. Use only the positioning fields shown in the REST example above (`path`, `line`, `side`) and include `subject_type` in the payload.

`gh pr view --json reviewThreads` is not supported. Use GraphQL.

Read threads:

```bash
gh api graphql \
  -F owner='OWNER' \
  -F repo='REPO' \
  -F number=123 \
  -f query='query($owner:String!, $repo:String!, $number:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$number) {
        reviewThreads(first:100) {
          nodes {
            id
            isResolved
            isOutdated
            viewerCanReply
            viewerCanResolve
            viewerCanUnresolve
            path
            line
            comments(first:50) {
              nodes {
                id
                fullDatabaseId
                author { login }
                body
                createdAt
                url
              }
            }
          }
        }
      }
    }
  }'
```

Reply to a thread by its id:

```bash
gh api graphql \
  -F threadId='THREAD_ID' \
  -F body='Reply body in Markdown.' \
  -f query='mutation($threadId:ID!, $body:String!) {
    addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$threadId, body:$body}) {
      comment { id url }
    }
  }'
```

REST fallback using the numeric `fullDatabaseId` of a review comment:

```bash
gh api repos/OWNER/REPO/pulls/comments/REVIEW_COMMENT_DATABASE_ID/replies \
  --method POST \
  -F body=@/tmp/review-thread-reply.md
```

Resolve or unresolve a thread:

```bash
gh api graphql \
  -F threadId='THREAD_ID' \
  -f query='mutation($threadId:ID!) {
    resolveReviewThread(input:{threadId:$threadId}) { thread { id isResolved } }
  }'

gh api graphql \
  -F threadId='THREAD_ID' \
  -f query='mutation($threadId:ID!) {
    unresolveReviewThread(input:{threadId:$threadId}) { thread { id isResolved } }
  }'
```

## Update a branch from main

```bash
git fetch origin
git checkout featureBranch
git merge origin/main
git status
git add path/to/file
git merge --continue
git push origin featureBranch
```

If the default branch is not `main`:

```bash
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'
```

## Safe patterns

```bash
gh issue view 218 --repo LeonFelipeCordero/matato
gh pr view 123 --repo LeonFelipeCordero/matato
cat <<'EOF' >/tmp/gh-body.md
Markdown body.
EOF
gh pr view 123 --json number,title,url --jq '{number, title, url}'
```
