import { afterEach, describe, expect, test } from "bun:test";
import { fetchPageContent, searchWeb } from "./webSearch.ts";

const originalFetch = globalThis.fetch;
const originalUrl = process.env.FIRECRAWL_URL;

afterEach(() => {
  globalThis.fetch = originalFetch;
  if (originalUrl === undefined) delete process.env.FIRECRAWL_URL;
  else process.env.FIRECRAWL_URL = originalUrl;
});

type FetchHandler = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

const setFetch = (handler: FetchHandler): void => {
  globalThis.fetch = Object.assign(handler, { preconnect: (): void => {} });
};

const searchResults = Array.from({ length: 14 }, (_, index) => ({
  title: `Result ${index}`,
  url: `https://example.com/${index}`,
  description: `Text ${index}`,
}));

describe("Firecrawl helpers", () => {
  test("posts to the local search API and normalizes results", async () => {
    delete process.env.FIRECRAWL_URL;
    setFetch(async (input, init) => {
      expect(String(input)).toBe("http://127.0.0.1:8888/v2/search");
      expect(init?.method).toBe("POST");
      expect(init?.headers).toEqual({ "Content-Type": "application/json" });
      expect(JSON.parse(String(init?.body))).toEqual({
        query: "query & terms",
        limit: 4,
        sources: ["web"],
      });
      return Response.json({
        success: true,
        data: {
          web: [
            {
              title: " Result ",
              url: "https://example.com",
              description: " text ",
            },
            { title: "Duplicate", url: "https://example.com" },
            { title: "", url: "https://valid.example" },
            { title: "Invalid", url: "javascript:alert(1)" },
            { title: "No snippet", url: "https://other.example" },
          ],
        },
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
        },
        {
          title: "No snippet",
          url: "https://other.example/",
          content: "",
          rawContent: "",
        },
      ],
    });
  });

  test("supports a Tailscale endpoint and caps each depth", async () => {
    process.env.FIRECRAWL_URL = "http://leon.tail3cac52.ts.net:8888/";
    setFetch(async (input) => {
      expect(String(input)).toBe(
        "http://leon.tail3cac52.ts.net:8888/v2/search",
      );
      return Response.json({ success: true, data: { web: searchResults } });
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
    expect(
      (await searchWeb({ query: "query", depthMode: "quick", maxResults: 0 }))
        .results,
    ).toHaveLength(1);
  });

  test("rejects empty queries, HTTP errors, and API failures", async () => {
    setFetch(async () => new Response("Forbidden", { status: 403 }));
    await expect(
      searchWeb({ query: " ", depthMode: "deep", maxResults: 1 }),
    ).rejects.toThrow("query is required");
    await expect(
      searchWeb({ query: "query", depthMode: "deep", maxResults: 1 }),
    ).rejects.toThrow("Firecrawl search failed: HTTP 403");
    setFetch(async () =>
      Response.json({ success: false, error: "Search unavailable" }),
    );
    await expect(
      searchWeb({ query: "query", depthMode: "quick", maxResults: 1 }),
    ).rejects.toThrow("Firecrawl search failed: Search unavailable");
  });

  test("returns empty results without fabricating evidence", async () => {
    for (const data of [{ web: [] }, {}]) {
      setFetch(async () => Response.json({ success: true, data }));
      expect(
        (await searchWeb({ query: "query", depthMode: "quick", maxResults: 5 }))
          .results,
      ).toEqual([]);
    }
  });

  test("scrapes Markdown and rejects invalid URLs and service errors", async () => {
    delete process.env.FIRECRAWL_URL;
    setFetch(async (input, init) => {
      expect(String(input)).toBe("http://127.0.0.1:8888/v2/scrape");
      expect(init?.method).toBe("POST");
      expect(JSON.parse(String(init?.body))).toEqual({
        url: "https://example.com/",
        formats: ["markdown"],
      });
      return Response.json({
        success: true,
        data: { markdown: " # Content " },
      });
    });
    await expect(
      fetchPageContent({ url: " https://example.com " }),
    ).resolves.toEqual({
      url: "https://example.com/",
      content: "# Content",
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
    ).rejects.toThrow("Firecrawl scrape failed: HTTP 404");
    setFetch(async () =>
      Response.json({ success: false, error: "Scrape blocked" }),
    );
    await expect(
      fetchPageContent({ url: "https://example.com" }),
    ).rejects.toThrow("Firecrawl scrape failed: Scrape blocked");
  });
});
