import { fetchPageContent } from './webSearch.mjs'

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

const parseInput = (args) => {
  const url = readFlagValue(args, 'url').trim()
  if (!url) {
    throw new Error('Usage: bun fetchPageContent.mjs --url "https://example.com"')
  }

  return { url }
}

try {
  const result = await fetchPageContent(parseInput(process.argv.slice(2)))
  console.log(JSON.stringify(result, null, 2))
} catch (error) {
  const message = error instanceof Error ? error.message : String(error)
  console.error(message)
  process.exit(1)
}
