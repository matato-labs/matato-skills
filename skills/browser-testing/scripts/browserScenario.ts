import { readFileSync } from "node:fs";

export type BrowserStep =
  | { action: "click" | "check" | "uncheck" | "hover"; target: string }
  | { action: "fill" | "select"; target: string; value: string }
  | { action: "press"; key: string }
  | { action: "expect"; text: string };

export type BrowserScenario = {
  name: string;
  steps: Array<BrowserStep>;
};

export const readScenario = (path: string): BrowserScenario =>
  JSON.parse(readFileSync(path, "utf8")) as BrowserScenario;

// Match a unique accessible label, never a ref supplied by the caller.
export const resolveTarget = (snapshot: string, target: string): string => {
  const matches = snapshot.split("\n").flatMap((line) => {
    const ref = /\[ref=(e\d+)\]/.exec(line);
    if (!ref) return [];
    const label = line
      .slice(0, ref.index)
      .trim()
      .replace(/^-\s*/, "")
      .replace(/\s*\[[^\]]*\]/g, "")
      .trim();
    return label === target ? [ref[1]] : [];
  });
  if (matches.length !== 1)
    throw new Error(
      `Target ${JSON.stringify(target)} matched ${matches.length} elements; use a unique exact label from the snapshot.`,
    );
  return matches[0];
};

export const stepArguments = (
  step: Exclude<BrowserStep, { action: "expect" }>,
  snapshot: string,
): Array<string> => {
  if (step.action === "press") return ["press", step.key];
  const ref = resolveTarget(snapshot, step.target);
  if (step.action === "fill" || step.action === "select")
    return [step.action, ref, step.value];
  return [step.action, ref];
};
