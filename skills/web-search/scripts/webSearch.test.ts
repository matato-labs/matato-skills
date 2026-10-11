import { afterEach, describe, expect, test } from "bun:test";
import { fetchPageContent, searchWeb } from "./webSearch.ts";

const originalFetch = globalThis.fetch;
const originalUrl = process.env.SEARXNG_URL;

afterEach(() => {
  globalThis.fetch = originalFetch;
  if (originalUrl === undefined) delete process.env.SEARXNG_URL;
  else process.env.SEARXNG_URL = originalUrl;
});

type FetchHandler = (input: RequestInfo | URL) => Promise<Response>;

const setFetch = (handler: FetchHandler): void => {
  globalThis.fetch = Object.assign(handler, { preconnect: (): void => {} });
};

const searchResults = Array.from({ length: 14 }, (_, index) => ({
  title: `Result ${index}`,
  url: `https://example.com/${index}`,
  content: `Text ${index}`,
  score: index,
}));

describe("SearXNG helpers", () => {
  test("uses the local JSON endpoint and normalizes results", async () => {
    delete process.env.SEARXNG_URL;
    let requestedUrl = "";
    setFetch(async (input) => {
      requestedUrl = String(input);
      return Response.json({
        results: [
          {
            title: " Result ",
            url: "https://example.com",
            content: " text ",
            score: 1,
          },
          { title: "Duplicate", url: "https://example.com", score: 2 },
          { title: "", url: "https://valid.example", score: 3 },
          { title: "Invalid", url: "javascript:alert(1)", score: 4 },
          { title: "No snippet", url: "https://other.example", score: 5 },
        ],
      });
    });

    await expect(
      searchWeb({
        query: " query & terms ",
        depthMode: "quick",
        maxResults: 99,
      }),
    ).resolves.toEqual({
      query: "query & terms",
      results: [
        {
          title: "Result",
          url: "https://example.com/",
          content: "text",
          rawContent: "",
          score: 1,
        },
        {
          title: "No snippet",
          url: "https://other.example/",
          content: "",
          rawContent: "",
          score: 5,
        },
      ],
    });
    const url = new URL(requestedUrl);
    expect(url.origin).toBe("http://127.0.0.1:8888");
    expect(url.pathname).toBe("/search");
    expect(url.searchParams.get("q")).toBe("query & terms");
    expect(url.searchParams.get("format")).toBe("json");
    expect(url.searchParams.get("categories")).toBe("general");
  });

  test("supports a Tailscale endpoint and caps each depth", async () => {
    process.env.SEARXNG_URL = "http://leon.tail3cac52.ts.net:8888/";
    setFetch(async (input) => {
      expect(new URL(String(input)).origin).toBe(
        "http://leon.tail3cac52.ts.net:8888",
      );
      return Response.json({ results: searchResults });
    });
    for (const depthMode of ["quick", "think", "deep"] as const) {
      const result = await searchWeb({
        query: "query",
        depthMode,
        maxResults: 99,
      });
      expect(result.results).toHaveLength(
        { quick: 4, think: 8, deep: 12 }[depthMode],
      );
    }
    expect(
      (await searchWeb({ query: "query", depthMode: "deep", maxResults: 2 }))
        .results,
    ).toHaveLength(2);
  });

  test("rejects empty queries and HTTP errors", async () => {
    setFetch(async () => new Response("Forbidden", { status: 403 }));
    await expect(
      searchWeb({ query: " ", depthMode: "deep", maxResults: 1 }),
    ).rejects.toThrow("query is required");
    await expect(
      searchWeb({ query: "query", depthMode: "deep", maxResults: 1 }),
    ).rejects.toThrow("SearXNG search failed: HTTP 403");
  });

  test("returns empty results without fabricating evidence", async () => {
    setFetch(async () => Response.json({ results: [] }));
    expect(
      (await searchWeb({ query: "query", depthMode: "quick", maxResults: 5 }))
        .results,
    ).toEqual([]);
  });

  test("fetches page HTML directly and rejects invalid URLs and HTTP errors", async () => {
    setFetch(async (input) => {
      expect(String(input)).toBe("https://example.com/");
      return new Response(" <html><body>content</body></html> ");
    });
    await expect(
      fetchPageContent({ url: " https://example.com " }),
    ).resolves.toEqual({
      url: "https://example.com/",
      content: "<html><body>content</body></html>",
    });
    await expect(fetchPageContent({ url: "not a URL" })).rejects.toThrow(
      "url is invalid",
    );
    await expect(
      fetchPageContent({ url: "file:///etc/passwd" }),
    ).rejects.toThrow("url is invalid");
    setFetch(async () => new Response("Not found", { status: 404 }));
    await expect(
      fetchPageContent({ url: "https://example.com" }),
    ).rejects.toThrow("Page fetch failed: HTTP 404");
  });
});
