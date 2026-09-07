import { readFlagValue } from "../../../src/cli.ts";
import { fetchPageContent } from "./webSearch.ts";

const parseInput = (args: string[]) => {
  const url = readFlagValue(args, "url").trim();
  if (!url)
    throw new Error(
      'Usage: bun fetchPageContent.ts --url "https://example.com"',
    );
  return { url };
};

try {
  console.log(
    JSON.stringify(
      await fetchPageContent(parseInput(process.argv.slice(2))),
      null,
      2,
    ),
  );
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
