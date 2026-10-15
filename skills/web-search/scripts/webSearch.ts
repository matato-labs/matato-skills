import { createHash } from "node:crypto";
import { mkdir, readFile, stat, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

type DepthMode = "quick" | "think" | "deep";

type SearchInput = {
  query: string;
  depthMode: DepthMode;
  maxResults: number;
};

type FetchPageContentInput = { url: string };

type BraveSearchResult = {
  title: string;
  url: string;
  description?: string;
};

type BraveSearchResponse = { web?: { results: Array<BraveSearchResult> } };

const depthResultLimits: Record<DepthMode, number> = {
  quick: 4,
  think: 8,
  deep: 12,
};

const normalizeUrl = (urlValue: string) => {
  try {
    const url = new URL(urlValue.trim());
    return url.protocol === "http:" || url.protocol === "https:"
      ? url.toString()
      : "";
  } catch {
    return "";
  }
};

const normalizeSearchResults = (
  results: Array<BraveSearchResult>,
  maxResults: number,
) => {
  const seenUrls = new Set<string>();
  const normalizedResults = [];

  for (const [index, result] of results.entries()) {
    const url = normalizeUrl(result.url);
    const title = result.title.trim();
    if (!title || !url || seenUrls.has(url)) continue;

    seenUrls.add(url);
    normalizedResults.push({
      title,
      url,
      content: (result.description ?? "").trim(),
      rawContent: "",
      score: 1 / (index + 1),
    });
    if (normalizedResults.length >= maxResults) break;
  }

  return normalizedResults;
};

const fetchSearchResults = async (url: URL, token: string) => {
  const cacheDirectory = join(
    process.env.XDG_CACHE_HOME || join(homedir(), ".cache"),
    "matato",
    "webSearch",
  );
  const cachePath = join(
    cacheDirectory,
    `${createHash("sha256").update(`${token}\n${url}`).digest("hex")}.json`,
  );
  try {
    const cachedFile = await stat(cachePath);
    if (Date.now() - cachedFile.mtimeMs < 300_000)
      return JSON.parse(
        await readFile(cachePath, "utf8"),
      ) as BraveSearchResponse;
  } catch {
    // A missing or unreadable cache must not prevent a search.
  }

  const response = await fetch(url, {
    headers: { Accept: "application/json", "X-Subscription-Token": token },
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok)
    throw new Error(`Brave search failed: HTTP ${response.status}`);
  const body = (await response.json()) as BraveSearchResponse;
  if (!body.web?.results.length) return body;

  try {
    await mkdir(cacheDirectory, { recursive: true, mode: 0o700 });
    await writeFile(cachePath, JSON.stringify(body), { mode: 0o600 });
  } catch {
    // Cache writes are best effort; return the upstream results regardless.
  }
  return body;
};

export const searchWeb = async (input: SearchInput) => {
  const query = input.query.trim();
  if (!query) throw new Error("query is required");

  const token = process.env.BRAVE_API_TOKEN?.trim();
  if (!token) throw new Error("BRAVE_API_TOKEN is required");

  const maxResults = Math.min(
    Math.max(1, input.maxResults),
    depthResultLimits[input.depthMode],
  );
  const url = new URL("https://api.search.brave.com/res/v1/web/search");
  url.searchParams.set("q", query);
  url.searchParams.set("count", "12");

  const body = await fetchSearchResults(url, token);
  return {
    query,
    results: normalizeSearchResults(body.web?.results ?? [], maxResults),
  };
};

export const fetchPageContent = async (input: FetchPageContentInput) => {
  const url = normalizeUrl(input.url);
  if (!url) throw new Error("url is invalid");

  const response = await fetch(url, { signal: AbortSignal.timeout(30_000) });
  if (!response.ok)
    throw new Error(`Page fetch failed: HTTP ${response.status}`);

  return { url, content: (await response.text()).trim() };
};
