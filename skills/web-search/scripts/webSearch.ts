type DepthMode = "quick" | "think" | "deep";

type SearchInput = {
  query: string;
  depthMode: DepthMode;
  maxResults: number;
};

type FetchPageContentInput = { url: string };

type TavilySearchResult = {
  title: string;
  url: string;
  content: string;
  raw_content?: string;
  score: number;
};

type TavilySearchResponse = { error?: string; results?: TavilySearchResult[] };
type TavilyExtractResponse = {
  error?: string;
  results?: Array<{ raw_content: string }>;
};

const depthResultLimits: Record<DepthMode, number> = {
  quick: 4,
  think: 8,
  deep: 12,
};

const resolveDepthResultLimit = (
  depthMode: DepthMode,
  requestedLimit: number,
) => Math.min(Math.max(1, requestedLimit), depthResultLimits[depthMode]);

const resolveSearchDepth = (depthMode: DepthMode) =>
  depthMode === "quick" ? "basic" : "advanced";

const normalizeUrl = (urlValue: string) => {
  const rawValue = urlValue.trim();
  if (!rawValue) return "";

  try {
    return new URL(rawValue).toString();
  } catch {
    return "";
  }
};

const isHighValueResult = (result: TavilySearchResult) =>
  result.title.trim().length > 0 &&
  normalizeUrl(result.url).length > 0 &&
  (result.content.trim().length > 0 ||
    (result.raw_content ?? "").trim().length > 0);

const normalizeSearchResults = (
  results: TavilySearchResult[],
  maxResults: number,
) => {
  const seenUrls = new Set<string>();
  const normalizedResults = [];

  for (const result of results) {
    const normalizedUrl = normalizeUrl(result.url);
    if (!isHighValueResult(result) || seenUrls.has(normalizedUrl)) continue;

    seenUrls.add(normalizedUrl);
    normalizedResults.push({
      title: result.title.trim(),
      url: normalizedUrl,
      content: result.content.trim(),
      rawContent: (result.raw_content ?? "").trim(),
      score: result.score,
    });
    if (normalizedResults.length >= maxResults) break;
  }

  return normalizedResults;
};

const ensureTavilyApiKey = () => {
  const resolvedApiKey = (process.env.TAVILY_API_KEY ?? "").trim();
  if (!resolvedApiKey) throw new Error("TAVILY_API_KEY is required");
  return resolvedApiKey;
};

const runTavilySearch = async (
  apiKey: string,
  input: SearchInput,
  maxResults: number,
) => {
  const response = await fetch("https://api.tavily.com/search", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      query: input.query,
      search_depth: resolveSearchDepth(input.depthMode),
      max_results: maxResults,
      include_raw_content: true,
      topic: "general",
    }),
  });
  return response.json() as Promise<TavilySearchResponse>;
};

const runTavilyExtract = async (
  apiKey: string,
  input: FetchPageContentInput,
) => {
  const response = await fetch("https://api.tavily.com/extract", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({ urls: [input.url], extract_depth: "basic" }),
  });
  return response.json() as Promise<TavilyExtractResponse>;
};

export const searchWeb = async (input: SearchInput) => {
  const query = input.query.trim();
  if (!query) throw new Error("query is required");

  const maxResults = resolveDepthResultLimit(input.depthMode, input.maxResults);
  const rawResponse = await runTavilySearch(
    ensureTavilyApiKey(),
    { ...input, query },
    maxResults,
  );
  if (rawResponse.error) throw new Error(rawResponse.error);

  return {
    query,
    results: normalizeSearchResults(rawResponse.results ?? [], maxResults),
  };
};

export const fetchPageContent = async (input: FetchPageContentInput) => {
  const url = normalizeUrl(input.url);
  if (!url) throw new Error("url is invalid");

  const rawResponse = await runTavilyExtract(ensureTavilyApiKey(), { url });
  if (rawResponse.error) throw new Error(rawResponse.error);

  return { url, content: rawResponse.results?.[0]?.raw_content.trim() ?? "" };
};
