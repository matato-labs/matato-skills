import { searchWeb } from './webSearch.mjs'

const readFlagValue = (args, name) => {
  const inlinePrefix = `--${name}=`
  const inlineValue = args.find((arg) => arg.startsWith(inlinePrefix))
  if (inlineValue) {
    return inlineValue.slice(inlinePrefix.length)
  }

  const flagIndex = args.indexOf(`--${name}`)
  if (flagIndex === -1) {
    return ''
  }

  return args[flagIndex + 1] ?? ''
}

const parseDepthMode = (value) => {
  if (value === 'think' || value === 'deep') {
    return value
  }

  return 'quick'
}

const parseMaxResults = (value) => {
  const parsedValue = Number.parseInt(value, 10)
  if (!Number.isFinite(parsedValue)) {
    return 5
  }

  return Math.min(Math.max(parsedValue, 1), 12)
}

const parseInput = (args) => {
  const query = readFlagValue(args, 'query').trim()
  if (!query) {
    throw new Error('Usage: bun searchWeb.mjs --query "search terms" [--depthMode quick|think|deep] [--maxResults 5]')
  }

  return {
    query,
    depthMode: parseDepthMode(readFlagValue(args, 'depthMode')),
    maxResults: parseMaxResults(readFlagValue(args, 'maxResults')),
  }
}

try {
  const result = await searchWeb(parseInput(process.argv.slice(2)))
  console.log(JSON.stringify(result, null, 2))
} catch (error) {
  const message = error instanceof Error ? error.message : String(error)
  console.error(message)
  process.exit(1)
}
