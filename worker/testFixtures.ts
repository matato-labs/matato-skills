import type { Automation } from "../src/automation.ts";

export const automation = (
  overrides: Partial<Automation> = {},
): Automation => ({
  jobName: "example",
  enabled: true,
  schedule: "0 * * * *",
  userPrompt: "Run the job",
  canOverlap: false,
  model: "test/model",
  thinkingLevel: "medium",
  canLaunchSubAgents: false,
  useSkill: false,
  ...overrides,
});

export function deferred(): { promise: Promise<void>; resolve: () => void } {
  let resolve = (): void => {};
  const promise = new Promise<void>((complete) => {
    resolve = complete;
  });
  return { promise, resolve };
}

export function piEvents(stopReason = "stop", errorMessage?: string): string {
  return (
    [
      { type: "session", version: 3 },
      { type: "agent_start" },
      {
        type: "message_end",
        message: { role: "assistant", stopReason, errorMessage },
      },
      { type: "agent_end", messages: [], willRetry: false },
      { type: "agent_settled" },
    ]
      .map((event) => JSON.stringify(event))
      .join("\n") + "\n"
  );
}
