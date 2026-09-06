import { fetchPageContent } from './webSearch.ts'

const readFlagValue = (args: string[], name: string) => {
  const inlinePrefix = `--${name}=`
  const inlineValue = args.find((arg) => arg.startsWith(inlinePrefix))
  if (inlineValue) return inlineValue.slice(inlinePrefix.length)

  const flagIndex = args.indexOf(`--${name}`)
  return flagIndex === -1 ? '' : args[flagIndex + 1] ?? ''
}

const parseInput = (args: string[]) => {
  const url = readFlagValue(args, 'url').trim()
  if (!url) throw new Error('Usage: bun fetchPageContent.ts --url "https://example.com"')
  return { url }
}

try {
  console.log(JSON.stringify(await fetchPageContent(parseInput(process.argv.slice(2))), null, 2))
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error))
  process.exit(1)
}
