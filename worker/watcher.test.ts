import { afterEach, describe, expect, test } from "bun:test";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createWatcher } from "./watcher.ts";
import { automation, deferred } from "./testFixtures.ts";

const cleanups: Array<() => void> = [];
afterEach(() => {
  for (const cleanup of cleanups.splice(0)) cleanup();
});

describe("worker config polling", () => {
  test("missing config stays alive; creation and deletion replace jobs", async () => {
    const root = await mkdtemp(join(tmpdir(), "workerWatcher"));
    const configPath = join(root, "config.json");
    const replacements: Array<Array<string>> = [];
    const errors: Array<string> = [];
    const watcher = createWatcher({
      configPath,
      replace: (jobs) => replacements.push(jobs.map((job) => job.jobName)),
      onReload: () => {},
      onError: (message) => errors.push(message),
    });
    try {
      await watcher.start();
      await watcher.poll();
      expect(replacements).toEqual([[]]);
      await writeFile(
        configPath,
        JSON.stringify({ automations: [automation()] }),
      );
      await watcher.poll();
      await watcher.poll();
      expect(replacements).toEqual([[], ["example"]]);
      await rm(configPath);
      await watcher.poll();
      expect(replacements).toEqual([[], ["example"], []]);
      expect(errors).toEqual([]);
    } finally {
      watcher.stop();
      await rm(root, { recursive: true, force: true });
    }
  });

  test("invalid config is retried without marking it applied", async () => {
    let valid = false;
    let loads = 0;
    let replacements = 0;
    const watcher = createWatcher({
      load: async () => {
        loads += 1;
        return { automations: [automation()] };
      },
      replace: () => {
        if (!valid) throw new Error("invalid schedule");
        replacements += 1;
      },
      onReload: () => {},
      onError: () => {},
    });
    cleanups.push(watcher.stop);
    await watcher.poll();
    valid = true;
    await watcher.poll();
    expect(loads).toBe(2);
    expect(replacements).toBe(1);
  });
});

describe("worker polling lifecycle", () => {
  test("polls are serialized and shutdown discards an in-flight load", async () => {
    const pending = deferred();
    let loads = 0;
    let replacements = 0;
    const watcher = createWatcher({
      load: async () => {
        loads += 1;
        await pending.promise;
        return { automations: [automation()] };
      },
      replace: () => {
        replacements += 1;
      },
      onReload: () => {},
      onError: () => {},
    });
    cleanups.push(watcher.stop);
    const first = watcher.poll();
    await Promise.resolve();
    await watcher.poll();
    watcher.stop();
    pending.resolve();
    await first;
    await watcher.start();
    expect(loads).toBe(1);
    expect(replacements).toBe(0);
  });

  test("poll interval reloads changes and stops cleanly", async () => {
    let content = "first";
    let replacements = 0;
    const watcher = createWatcher({
      load: async () => ({
        automations: [automation({ userPrompt: content })],
      }),
      replace: () => {
        replacements += 1;
      },
      onReload: () => {},
      onError: () => {},
      pollMs: 10,
    });
    cleanups.push(watcher.stop);
    await watcher.start();
    content = "second";
    await Bun.sleep(30);
    expect(replacements).toBe(2);
    watcher.stop();
    content = "third";
    await Bun.sleep(30);
    expect(replacements).toBe(2);
  });
});
