const depthResultLimits = {
  quick: 4,
  think: 8,
  deep: 12,
}

const resolveDepthResultLimit = (depthMode, requestedLimit) => {
  const safeRequestedLimit = Math.max(1, requestedLimit)
  const modeLimit = depthResultLimits[depthMode] ?? depthResultLimits.quick
  return Math.min(safeRequestedLimit, modeLimit)
}

const resolveSearchDepth = (depthMode) => {
  if (depthMode === 'quick') {
    return 'basic'
  }

  return 'advanced'
}

const normalizeUrl = (urlValue) => {
  const rawValue = urlValue.trim()
  if (!rawValue) {
    return ''
  }

  try {
    return new URL(rawValue).toString()
  } catch {
    return ''
  }
}

const isHighValueResult = (result) => {
  const hasTitle = result.title.trim().length > 0
  const hasContent = result.content.trim().length > 0
  const hasRawContent = (result.raw_content ?? '').trim().length > 0
  const hasValidUrl = normalizeUrl(result.url).length > 0

  return hasTitle && hasValidUrl && (hasContent || hasRawContent)
}

const normalizeSearchResults = (results, maxResults) => {
  const seenUrls = new Set()
  const normalizedResults = []

  for (const result of results) {
    if (!isHighValueResult(result)) {
      continue
    }

    const normalizedUrl = normalizeUrl(result.url)
    if (!normalizedUrl || seenUrls.has(normalizedUrl)) {
      continue
    }

    seenUrls.add(normalizedUrl)
    normalizedResults.push({
      title: result.title.trim(),
      url: normalizedUrl,
      content: result.content.trim(),
      rawContent: (result.raw_content ?? '').trim(),
      score: result.score,
    })

    if (normalizedResults.length >= maxResults) {
      break
    }
  }

  return normalizedResults
}

const ensureTavilyApiKey = () => {
  const resolvedApiKey = (process.env.TAVILY_API_KEY ?? '').trim()
  if (!resolvedApiKey) {
    throw new Error('TAVILY_API_KEY is required')
  }

  return resolvedApiKey
}

const runTavilySearch = async (apiKey, input, maxResults) => {
  const response = await fetch('https://api.tavily.com/search', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      query: input.query,
      search_depth: resolveSearchDepth(input.depthMode),
      max_results: maxResults,
      include_raw_content: true,
      topic: 'general',
    }),
  })

  return response.json()
}

const runTavilyExtract = async (apiKey, input) => {
  const response = await fetch('https://api.tavily.com/extract', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      urls: [input.url],
      extract_depth: 'basic',
    }),
  })

  return response.json()
}

export const searchWeb = async (input) => {
  const query = input.query.trim()
  if (!query) {
    throw new Error('query is required')
  }

  const apiKey = ensureTavilyApiKey()
  const maxResults = resolveDepthResultLimit(input.depthMode, input.maxResults)
  const rawResponse = await runTavilySearch(apiKey, { ...input, query }, maxResults)
  if (rawResponse.error) {
    throw new Error(rawResponse.error)
  }

  const rawResults = rawResponse.results ?? []
  return {
    query,
    results: normalizeSearchResults(rawResults, maxResults),
  }
}

export const fetchPageContent = async (input) => {
  const normalizedUrl = normalizeUrl(input.url)
  if (!normalizedUrl) {
    throw new Error('url is invalid')
  }

  const apiKey = ensureTavilyApiKey()
  const rawResponse = await runTavilyExtract(apiKey, { url: normalizedUrl })
  if (rawResponse.error) {
    throw new Error(rawResponse.error)
  }

  const firstResult = rawResponse.results?.[0]
  if (!firstResult) {
    return {
      url: normalizedUrl,
      content: '',
    }
  }

  return {
    url: normalizedUrl,
    content: firstResult.raw_content.trim(),
  }
}
