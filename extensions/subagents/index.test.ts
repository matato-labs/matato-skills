import { describe, expect, mock, spyOn, test } from "bun:test";
import * as childProcess from "node:child_process";
import { EventEmitter } from "node:events";
import type {
  AgentBeforeSettleEvent,
  AgentBeforeSettleEventResult,
  ExtensionAPI,
  ExtensionHandler,
  ExtensionToolContext,
  ToolDefinition,
} from "@earendil-works/pi-coding-agent";
import subagents, { runConcurrent } from "./index.ts";

const priorEntry = {
  type: "custom_message",
  customType: "review-reminder",
  content: "Review the final diff before replying.",
  display: false,
} as const;

const beforeSettle: AgentBeforeSettleEvent = {
  type: "agent_before_settle",
  entries: [priorEntry],
  continue: false,
  outcome: "completed",
  context: {
    contextEntries: [],
    contextMessages: [],
    llmMessages: [],
    pendingMessages: [],
    canContinue: false,
  },
};

test.each(["tui", "print", "json"] as const)(
  "launches in the background and delivers results in %s mode",
  async (mode) => {
    const workers = Array.from({ length: 2 }, () =>
      Object.assign(new EventEmitter(), {
        stdout: new EventEmitter(),
        stderr: new EventEmitter(),
        kill: () => true,
      }),
    );
    const spawn = spyOn(childProcess, "spawn")
      .mockReturnValueOnce(workers[0] as childProcess.ChildProcess)
      .mockReturnValueOnce(workers[1] as childProcess.ChildProcess);
    const delivered =
      Promise.withResolvers<Parameters<ExtensionAPI["sendMessage"]>>();
    const sendMessage = mock<ExtensionAPI["sendMessage"]>((...args) =>
      delivered.resolve(args),
    );
    const registerTool = mock<(tool: ToolDefinition) => void>();
    const ui: Partial<ExtensionToolContext["ui"]> = { notify: mock() };
    const context: Partial<ExtensionToolContext> = {
      cwd: process.cwd(),
      mode,
      model: { provider: "test", id: "test" } as ExtensionToolContext["model"],
      ui: ui as ExtensionToolContext["ui"],
    };
    type SettleHandler = ExtensionHandler<
      AgentBeforeSettleEvent,
      AgentBeforeSettleEventResult
    >;
    let settleHandler: SettleHandler | undefined;
    const api: Partial<ExtensionAPI> = {
      registerTool: registerTool as ExtensionAPI["registerTool"],
      sendMessage,
      on: (event, handler) => {
        if (event === "agent_before_settle")
          settleHandler = handler as SettleHandler;
        return () => {
          settleHandler = undefined;
        };
      },
    };

    try {
      subagents(api as ExtensionAPI);
      const tool = registerTool.mock.calls[0][0];
      const acknowledgement = await tool.execute(
        "call-1",
        {
          tasks: [
            { prompt: "Find a question" },
            { prompt: "Find an edge case" },
          ],
        },
        undefined,
        undefined,
        context as ExtensionToolContext,
      );
      expect(acknowledgement.content).toEqual([
        { type: "text", text: expect.stringContaining("in the background") },
      ]);
      expect(sendMessage.mock.calls).toHaveLength(0);

      const settle = () =>
        settleHandler?.(beforeSettle, context as ExtensionToolContext);
      const settlement = settle();
      if (mode === "tui") expect(await settlement).toBeUndefined();

      workers[1].stderr.emit("data", Buffer.from("Worker failed"));
      workers[1].emit("close", 1);
      workers[0].stdout.emit(
        "data",
        Buffer.from("What should happen offline?"),
      );
      workers[0].emit("close", 0);

      const content =
        "Subagent results for call-1:\n\n## Task 1: finished\n\nWhat should happen offline?\n\n## Task 2: failed\n\nWorker failed";
      if (mode === "tui") {
        const [message, delivery] = await delivered.promise;
        expect(message.content).toBe(content);
        expect(delivery).toEqual({ triggerTurn: false });
      } else {
        expect(await settlement).toEqual({
          entries: [
            priorEntry,
            {
              type: "custom_message",
              customType: "subagent-results",
              content,
              display: true,
            },
          ],
          continue: true,
        });
        expect(sendMessage.mock.calls).toHaveLength(0);
        expect(await settle()).toBeUndefined();
      }
    } finally {
      spawn.mockRestore();
    }
  },
  1_000,
);

describe("runConcurrent", () => {
  test("starts more than four tasks concurrently and preserves input order", async () => {
    let active = 0;
    let peakActive = 0;
    const started: Array<number> = [];
    const release: Array<() => void> = [];
    const tasks = ["first", "second", "third", "fourth", "fifth"];

    const batch = runConcurrent(
      tasks,
      (task, index) =>
        new Promise<string>((resolve) => {
          active += 1;
          peakActive = Math.max(peakActive, active);
          started.push(index);
          release[index] = () => {
            active -= 1;
            resolve(task);
          };
        }),
    );

    await Promise.resolve();
    expect(peakActive).toBe(tasks.length);
    expect(started).toEqual([0, 1, 2, 3, 4]);

    release[4]();
    await Promise.resolve();
    let completed = false;
    void batch.then(() => {
      completed = true;
    });
    await Promise.resolve();
    expect(completed).toBe(false);
    release[3]();
    release[2]();
    release[1]();
    release[0]();

    await expect(batch).resolves.toEqual(tasks);
    expect(active).toBe(0);
  });

  test("keeps successful results when another task reports a failure", async () => {
    const results = await runConcurrent(
      ["succeeds", "fails", "also succeeds"],
      async (task) =>
        task === "fails"
          ? { task, status: "failed" }
          : { task, status: "finished" },
    );

    expect(results).toEqual([
      { task: "succeeds", status: "finished" },
      { task: "fails", status: "failed" },
      { task: "also succeeds", status: "finished" },
    ]);
  });
});
