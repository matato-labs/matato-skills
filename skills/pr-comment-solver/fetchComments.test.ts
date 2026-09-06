import {
  afterEach,
  beforeEach,
  describe,
  expect,
  spyOn,
  test,
} from 'bun:test'
import { createFetchComments, runGhApiGraphQL } from './fetchComments.ts'

const testPullRequestUrl = 'https://github.com/LeonFelipeCordero/matato/pull/309'

type ShellOutput = Awaited<ReturnType<typeof Bun.$>>

const createShellOutput = (response: unknown): ShellOutput => {
  return {
    exitCode: 0,
    json: async () => response,
  } as ShellOutput
}

describe('createFetchComments', () => {
  const originalPrompt = Bun.env.SEQUENCE_STEP_PROMPT

  beforeEach(() => {
    Bun.env.SEQUENCE_STEP_PROMPT = testPullRequestUrl
  })

  afterEach(() => {
    if (originalPrompt) {
      Bun.env.SEQUENCE_STEP_PROMPT = originalPrompt
      return
    }

    delete Bun.env.SEQUENCE_STEP_PROMPT
  })

  test('skips when there are no unresolved threads', async () => {
    const { run } = createFetchComments({
      executeGraphQL: async () => ({
        data: {
          repository: {
            pullRequest: {
              reviewThreads: {
                nodes: [
                  {
                    id: 'thread-1',
                    isResolved: true,
                    isOutdated: false,
                    comments: { nodes: [] },
                  },
                ],
              },
            },
          },
        },
      }),
    })

    const result = await run()

    expect(result).toEqual({ skip: true, reason: 'No unresolved comments' })
  })

  test('returns unresolved threads', async () => {
    const { run } = createFetchComments({
      executeGraphQL: async () => ({
        data: {
          repository: {
            pullRequest: {
              reviewThreads: {
                nodes: [
                  {
                    id: 'thread-1',
                    isResolved: false,
                    isOutdated: false,
                    comments: {
                      nodes: [
                        {
                          id: 'comment-1',
                          body: 'AGENT: fix this',
                          path: 'src/file.ts',
                          line: 10,
                          originalLine: 10,
                          diffHunk: '',
                        },
                      ],
                    },
                  },
                ],
              },
            },
          },
        },
      }),
    })

    const result = await run()

    expect(result).toEqual({
      comments: [
        {
          id: 'thread-1',
          isResolved: false,
          isOutdated: false,
          comments: [
            {
              id: 'comment-1',
              body: 'AGENT: fix this',
              path: 'src/file.ts',
              line: 10,
              originalLine: 10,
              diffHunk: '',
            },
          ],
        },
      ],
    })
  })

  test('throws when SEQUENCE_STEP_PROMPT is missing', async () => {
    const { run } = createFetchComments({
      executeGraphQL: async () => ({ data: undefined }),
    })
    delete Bun.env.SEQUENCE_STEP_PROMPT

    await expect(run()).rejects.toThrow('SEQUENCE_STEP_PROMPT must be set')
  })

  test('throws when prompt has no pull request URL', async () => {
    const { run } = createFetchComments({
      executeGraphQL: async () => ({ data: undefined }),
    })
    Bun.env.SEQUENCE_STEP_PROMPT = 'no url here'

    await expect(run()).rejects.toThrow('Could not find a pull request URL')
  })

  test('passes query variables to the GraphQL executor', async () => {
    const calls: Array<{
      owner: string
      repo: string
      number: number
    }> = []
    const { run } = createFetchComments({
      executeGraphQL: async (input) => {
        calls.push({
          owner: input.owner,
          repo: input.repo,
          number: input.number,
        })
        return {
          data: {
            repository: {
              pullRequest: {
                reviewThreads: { nodes: [] },
              },
            },
          },
        }
      },
    })

    await run()

    expect(calls).toEqual([
      { owner: 'LeonFelipeCordero', repo: 'matato', number: 309 },
    ])
  })
})

describe('runGhApiGraphQL', () => {
  test('returns parsed response', async () => {
    const response = {
      data: {
        repository: {
          pullRequest: {
            reviewThreads: { nodes: [] },
          },
        },
      },
    }
    const shellSpy = spyOn(Bun, '$').mockResolvedValue(createShellOutput(response))

    try {
      const result = await runGhApiGraphQL({
        query: 'query',
        owner: 'owner',
        repo: 'repo',
        number: 1,
      })

      expect(result).toEqual(response)
    } finally {
      shellSpy.mockRestore()
    }
  })

  test('throws a descriptive error on GraphQL errors', async () => {
    const shellSpy = spyOn(Bun, '$').mockResolvedValue(
      createShellOutput({ errors: [{ message: 'Rate limit exceeded' }] }),
    )

    try {
      await expect(
        runGhApiGraphQL({
          query: 'query',
          owner: 'owner',
          repo: 'repo',
          number: 1,
        }),
      ).rejects.toThrow('GraphQL error: Rate limit exceeded')
    } finally {
      shellSpy.mockRestore()
    }
  })
})
