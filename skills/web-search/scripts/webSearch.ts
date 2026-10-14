type DepthMode = "quick" | "think" | "deep";

type SearchInput = {
  query: string;
  depthMode: DepthMode;
  maxResults: number;
};

type FetchPageContentInput = { url: string };

type FirecrawlSearchResult = {
  title: string;
  url: string;
  description?: string;
};

type FirecrawlResponse<Data> =
  { success: true; data: Data } | { success: false; error: string };

type SearchData = { web?: Array<FirecrawlSearchResult> };
type ScrapeData = { markdown?: string };

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
  results: Array<FirecrawlSearchResult>,
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
      content: (result.description ?? "").trim(),
      rawContent: "",
    });
    if (normalizedResults.length >= maxResults) break;
  }

  return normalizedResults;
};

const requestFirecrawl = async <Data>(
  endpoint: "search" | "scrape",
  input:
    | { query: string; limit: number; sources: Array<"web"> }
    | {
        url: string;
        formats: Array<"markdown">;
      },
): Promise<Data> => {
  const baseUrl = process.env.FIRECRAWL_URL?.trim() || "http://127.0.0.1:8888";
  const url = new URL(`v2/${endpoint}`, `${baseUrl.replace(/\/$/, "")}/`);
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
    signal: AbortSignal.timeout(90_000),
  });
  if (!response.ok)
    throw new Error(`Firecrawl ${endpoint} failed: HTTP ${response.status}`);
  const body = (await response.json()) as FirecrawlResponse<Data>;
  if (!body.success)
    throw new Error(`Firecrawl ${endpoint} failed: ${body.error}`);
  return body.data;
};

export const searchWeb = async (input: SearchInput) => {
  const query = input.query.trim();
  if (!query) throw new Error("query is required");

  const maxResults = Math.min(
    Math.max(1, input.maxResults),
    depthResultLimits[input.depthMode],
  );
  const data = await requestFirecrawl<SearchData>("search", {
    query,
    limit: maxResults,
    sources: ["web"],
  });

  return { query, results: normalizeSearchResults(data.web ?? [], maxResults) };
};

export const fetchPageContent = async (input: FetchPageContentInput) => {
  const url = normalizeUrl(input.url);
  if (!url) throw new Error("url is invalid");

  const data = await requestFirecrawl<ScrapeData>("scrape", {
    url,
    formats: ["markdown"],
  });
  return { url, content: (data.markdown ?? "").trim() };
};
