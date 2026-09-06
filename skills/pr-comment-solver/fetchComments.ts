type ReviewThreadComment = {
  id: string
  body: string
  path: string
  line: number | null
  originalLine: number | null
  diffHunk: string
}

type ReviewThread = {
  id: string
  isResolved: boolean
  isOutdated: boolean
  comments: Array<ReviewThreadComment>
}

type ReviewThreadNode = {
  id: string
  isResolved: boolean
  isOutdated: boolean
  comments: { nodes: Array<ReviewThreadComment> }
}

type ReviewThreadsData = {
  repository: {
    pullRequest: {
      reviewThreads: {
        nodes: Array<ReviewThreadNode>
      }
    }
  }
}

type GraphQLResponse = {
  data?: ReviewThreadsData
  errors?: Array<{ message: string }>
}

type GraphQLExecutor = (input: {
  query: string
  owner: string
  repo: string
  number: number
}) => Promise<GraphQLResponse>

const pullRequestUrlPattern =
  /https:\/\/github\.com\/([^/]+)\/([^/]+)\/pull\/(\d+)/

// The query caps review threads and comments at 100 per page. Increase
// the `first:` values or add pagination (pageInfo/endCursor) if large PRs
// become common.
const reviewThreadsQuery = `
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            isOutdated
            comments(first: 100) {
              nodes {
                id
                body
                path
                line
                originalLine
                diffHunk
              }
            }
          }
        }
      }
    }
  }
`

const extractPullRequestUrl = (prompt: string): string | null => {
  const match = prompt.match(pullRequestUrlPattern)
  if (!match) {
    return null
  }

  return match[0]
}

const parsePullRequestUrl = (
  url: string,
): { owner: string; repo: string; number: number } => {
  const match = url.match(pullRequestUrlPattern)
  if (!match) {
    throw new Error(`Could not parse pull request URL: ${url}`)
  }

  return {
    owner: match[1],
    repo: match[2],
    number: Number.parseInt(match[3], 10),
  }
}

export const runGhApiGraphQL = async (input: {
  query: string
  owner: string
  repo: string
  number: number
}): Promise<GraphQLResponse> => {
  let result: { json(): Promise<unknown> }

  try {
    result = await Bun.$`gh api graphql -f query=${input.query} -F owner=${input.owner} -F repo=${input.repo} -F number=${input.number}`
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    throw new Error(`GitHub CLI request failed: ${message}`)
  }

  const response = (await result.json()) as GraphQLResponse

  if (response.errors) {
    const messages = response.errors.map((error) => error.message).join(', ')
    throw new Error(`GraphQL error: ${messages}`)
  }

  return response
}

const fetchReviewThreads = async (input: {
  owner: string
  repo: string
  number: number
  executeGraphQL: GraphQLExecutor
}): Promise<Array<ReviewThread>> => {
  const response = await input.executeGraphQL({
    query: reviewThreadsQuery,
    owner: input.owner,
    repo: input.repo,
    number: input.number,
  })

  const nodes = response.data?.repository?.pullRequest?.reviewThreads?.nodes

  if (!nodes) {
    return []
  }

  return nodes.map((thread) => ({
    id: thread.id,
    isResolved: thread.isResolved,
    isOutdated: thread.isOutdated,
    comments: thread.comments.nodes,
  }))
}

export const createFetchComments = (deps: {
  executeGraphQL: GraphQLExecutor
}): {
  run: () => Promise<
    | { skip: true; reason: string }
    | { comments: Array<ReviewThread> }
  >
} => {
  return {
    run: async () => {
      const prompt = Bun.env.SEQUENCE_STEP_PROMPT
      if (!prompt) {
        throw new Error('SEQUENCE_STEP_PROMPT must be set')
      }

      const pullRequestUrl = extractPullRequestUrl(prompt)
      if (!pullRequestUrl) {
        throw new Error('Could not find a pull request URL in the prompt')
      }

      const { owner, repo, number } = parsePullRequestUrl(pullRequestUrl)
      const threads = await fetchReviewThreads({
        owner,
        repo,
        number,
        executeGraphQL: deps.executeGraphQL,
      })
      const unresolvedThreads = threads.filter((thread) => !thread.isResolved)

      if (unresolvedThreads.length === 0) {
        return { skip: true, reason: 'No unresolved comments' }
      }

      return { comments: unresolvedThreads }
    },
  }
}

export const run = createFetchComments({
  executeGraphQL: runGhApiGraphQL,
}).run
