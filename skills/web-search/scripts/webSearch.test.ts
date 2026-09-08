import { afterEach, describe, expect, test } from "bun:test";
import { fetchPageContent, searchWeb } from "./webSearch.ts";

const originalFetch = globalThis.fetch;
const originalKey = process.env.TAVILY_API_KEY;

afterEach(() => {
  globalThis.fetch = originalFetch;
  if (originalKey === undefined) delete process.env.TAVILY_API_KEY;
  else process.env.TAVILY_API_KEY = originalKey;
});

type MockResponse = {
  error?: string;
  results?: Array<{ raw_content?: string }>;
};
type FetchHandler = (options?: RequestInit) => Promise<Response>;

const setFetch = (handler: FetchHandler): void => {
  globalThis.fetch = Object.assign(
    async (_input: RequestInfo | URL, options?: RequestInit) =>
      handler(options),
    { preconnect: (): void => {} },
  );
};

const mockFetch = (body: MockResponse): void => {
  setFetch(
    async () =>
      new Response(JSON.stringify(body), {
        status: 200,
      }),
  );
};

describe("Tavily helpers", () => {
  test("normalizes a query, caps quick results, and drops invalid duplicates", async () => {
    process.env.TAVILY_API_KEY = "key";
    let request: RequestInit | undefined;
    setFetch(async (options) => {
      request = options;
      return new Response(
        JSON.stringify({
          results: [
            {
              title: " Result ",
              url: "https://example.com",
              content: " text ",
              score: 1,
            },
            {
              title: "Duplicate",
              url: "https://example.com",
              content: "text",
              score: 2,
            },
            {
              title: "",
              url: "https://valid.example",
              content: "text",
              score: 3,
            },
          ],
        }),
      );
    });

    await expect(
      searchWeb({ query: " query ", depthMode: "quick", maxResults: 99 }),
    ).resolves.toEqual({
      query: "query",
      results: [
        {
          title: "Result",
          url: "https://example.com/",
          content: "text",
          rawContent: "",
          score: 1,
        },
      ],
    });
    expect(JSON.parse(String(request?.body))).toMatchObject({
      query: "query",
      search_depth: "basic",
      max_results: 4,
    });
  });

  test("rejects missing inputs and API errors", async () => {
    delete process.env.TAVILY_API_KEY;
    await expect(
      searchWeb({ query: "query", depthMode: "think", maxResults: 1 }),
    ).rejects.toThrow("TAVILY_API_KEY is required");
    process.env.TAVILY_API_KEY = "key";
    mockFetch({ error: "Tavily rejected request" });
    await expect(
      searchWeb({ query: " ", depthMode: "deep", maxResults: 1 }),
    ).rejects.toThrow("query is required");
    await expect(
      searchWeb({ query: "query", depthMode: "deep", maxResults: 1 }),
    ).rejects.toThrow("Tavily rejected request");
  });

  test("normalizes extraction URLs and returns extracted content", async () => {
    process.env.TAVILY_API_KEY = "key";
    mockFetch({ results: [{ raw_content: " content " }] });
    await expect(
      fetchPageContent({ url: " https://example.com " }),
    ).resolves.toEqual({ url: "https://example.com/", content: "content" });
    await expect(fetchPageContent({ url: "not a URL" })).rejects.toThrow(
      "url is invalid",
    );
  });
});
