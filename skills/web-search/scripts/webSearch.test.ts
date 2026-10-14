import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdtemp, readdir, rm, utimes, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fetchPageContent, searchWeb } from "./webSearch.ts";

const originalFetch = globalThis.fetch;
const originalUrl = process.env.SEARXNG_URL;
const originalCacheHome = process.env.XDG_CACHE_HOME;
let cacheHome = "";

beforeEach(async () => {
  cacheHome = await mkdtemp(join(tmpdir(), "webSearch"));
  process.env.XDG_CACHE_HOME = cacheHome;
});

afterEach(async () => {
  await rm(cacheHome, { recursive: true, force: true });
  if (originalCacheHome === undefined) delete process.env.XDG_CACHE_HOME;
  else process.env.XDG_CACHE_HOME = originalCacheHome;
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

  test("reuses disk results across depths and refreshes expired entries", async () => {
    let requests = 0;
    setFetch(async () => {
      requests += 1;
      return Response.json({ results: searchResults });
    });
    const input = {
      query: "cached query",
      depthMode: "quick",
      maxResults: 12,
    } as const;
    expect((await searchWeb(input)).results).toHaveLength(4);
    expect(
      (await searchWeb({ ...input, depthMode: "deep" })).results,
    ).toHaveLength(12);
    expect(requests).toBe(1);

    const directory = join(cacheHome, "matato", "webSearch");
    const [file] = await readdir(directory);
    const expiredTime = new Date(Date.now() - 301_000);
    await utimes(join(directory, file!), expiredTime, expiredTime);
    await searchWeb(input);
    expect(requests).toBe(2);

    await writeFile(join(directory, file!), "broken JSON");
    await searchWeb(input);
    expect(requests).toBe(3);
  });

  test("keeps query and endpoint caches separate", async () => {
    let requests = 0;
    setFetch(async () => {
      requests += 1;
      return Response.json({ results: searchResults });
    });
    const input = {
      query: "first",
      depthMode: "quick",
      maxResults: 1,
    } as const;
    await searchWeb(input);
    await searchWeb({ ...input, query: "second" });
    process.env.SEARXNG_URL = "http://other.example:8888";
    await searchWeb(input);
    expect(requests).toBe(3);
  });

  test("still searches when the cache directory is unwritable", async () => {
    const blockedPath = join(cacheHome, "blocked");
    await writeFile(blockedPath, "not a directory");
    process.env.XDG_CACHE_HOME = blockedPath;
    setFetch(async () => Response.json({ results: searchResults }));
    expect(
      (await searchWeb({ query: "query", depthMode: "quick", maxResults: 1 }))
        .results,
    ).toHaveLength(1);
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
    let requests = 0;
    setFetch(async () => {
      requests += 1;
      return Response.json({ results: [] });
    });
    const input = {
      query: "query",
      depthMode: "quick",
      maxResults: 5,
    } as const;
    expect((await searchWeb(input)).results).toEqual([]);
    expect((await searchWeb(input)).results).toEqual([]);
    expect(requests).toBe(2);
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
