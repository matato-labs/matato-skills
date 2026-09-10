import { describe, expect, test } from "bun:test";
import { runBounded } from "./index.ts";

describe("runBounded", () => {
  test("limits concurrent tasks and preserves input order", async () => {
    let active = 0;
    let peakActive = 0;
    const started: Array<number> = [];
    const release: Array<() => void> = [];
    const tasks = ["first", "second", "third", "fourth", "fifth"];

    const batch = runBounded(
      tasks,
      2,
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
    expect(peakActive).toBe(2);
    expect(started).toEqual([0, 1]);

    release[1]();
    await Promise.resolve();
    expect(started).toEqual([0, 1, 2]);

    release[0]();
    release[2]();
    await Promise.resolve();
    release[3]();
    await Promise.resolve();
    release[4]();

    await expect(batch).resolves.toEqual(tasks);
    expect(peakActive).toBe(2);
  });

  test("keeps successful results when another task reports a failure", async () => {
    const results = await runBounded(
      ["succeeds", "fails", "also succeeds"],
      4,
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
