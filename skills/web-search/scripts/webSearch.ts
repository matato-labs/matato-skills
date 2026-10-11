type DepthMode = "quick" | "think" | "deep";

type SearchInput = {
  query: string;
  depthMode: DepthMode;
  maxResults: number;
};

type FetchPageContentInput = { url: string };

type SearxngSearchResult = {
  title: string;
  url: string;
  content?: string;
  score: number;
};

type SearxngSearchResponse = { results: Array<SearxngSearchResult> };

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
  results: Array<SearxngSearchResult>,
  maxResults: number,
) => {
  const seenUrls = new Set<string>();
  const normalizedResults = [];

  for (const result of results) {
    const url = normalizeUrl(result.url);
    const title = result.title.trim();
    if (!title || !url || seenUrls.has(url)) continue;

    seenUrls.add(url);
    normalizedResults.push({
      title,
      url,
      content: (result.content ?? "").trim(),
      rawContent: "",
      score: result.score,
    });
    if (normalizedResults.length >= maxResults) break;
  }

  return normalizedResults;
};

export const searchWeb = async (input: SearchInput) => {
  const query = input.query.trim();
  if (!query) throw new Error("query is required");

  const maxResults = Math.min(
    Math.max(1, input.maxResults),
    depthResultLimits[input.depthMode],
  );
  const baseUrl = process.env.SEARXNG_URL?.trim() || "http://127.0.0.1:8888";
  const url = new URL("search", `${baseUrl.replace(/\/$/, "")}/`);
  url.searchParams.set("q", query);
  url.searchParams.set("format", "json");
  url.searchParams.set("categories", "general");

  const response = await fetch(url, { signal: AbortSignal.timeout(30_000) });
  if (!response.ok)
    throw new Error(`SearXNG search failed: HTTP ${response.status}`);
  const body = (await response.json()) as SearxngSearchResponse;

  return { query, results: normalizeSearchResults(body.results, maxResults) };
};

export const fetchPageContent = async (input: FetchPageContentInput) => {
  const url = normalizeUrl(input.url);
  if (!url) throw new Error("url is invalid");

  const response = await fetch(url, { signal: AbortSignal.timeout(30_000) });
  if (!response.ok)
    throw new Error(`Page fetch failed: HTTP ${response.status}`);

  return { url, content: (await response.text()).trim() };
};
