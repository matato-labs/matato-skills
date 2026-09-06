import { searchWeb } from './webSearch.ts'

type DepthMode = 'quick' | 'think' | 'deep'

const readFlagValue = (args: string[], name: string) => {
  const inlinePrefix = `--${name}=`
  const inlineValue = args.find((arg) => arg.startsWith(inlinePrefix))
  if (inlineValue) return inlineValue.slice(inlinePrefix.length)

  const flagIndex = args.indexOf(`--${name}`)
  return flagIndex === -1 ? '' : args[flagIndex + 1] ?? ''
}

const parseDepthMode = (value: string): DepthMode => value === 'think' || value === 'deep' ? value : 'quick'

const parseMaxResults = (value: string) => {
  const parsedValue = Number.parseInt(value, 10)
  return Number.isFinite(parsedValue) ? Math.min(Math.max(parsedValue, 1), 12) : 5
}

const parseInput = (args: string[]) => {
  const query = readFlagValue(args, 'query').trim()
  if (!query) throw new Error('Usage: bun searchWeb.ts --query "search terms" [--depthMode quick|think|deep] [--maxResults 5]')
  return { query, depthMode: parseDepthMode(readFlagValue(args, 'depthMode')), maxResults: parseMaxResults(readFlagValue(args, 'maxResults')) }
}

try {
  console.log(JSON.stringify(await searchWeb(parseInput(process.argv.slice(2))), null, 2))
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error))
  process.exit(1)
}
