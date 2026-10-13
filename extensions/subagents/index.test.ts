import { describe, expect, test } from "bun:test";
import { runConcurrent } from "./index.ts";

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
