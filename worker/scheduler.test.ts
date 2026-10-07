import { afterEach, describe, expect, test } from "bun:test";
import { Cron } from "croner";
import { createScheduler, type ScheduleFactory } from "./scheduler.ts";
import { automation, deferred } from "./testFixtures.ts";

type FakeSchedule = {
  run: () => Promise<void>;
  stopped: boolean;
  resumed: boolean;
};
const cleanups: Array<() => void> = [];
afterEach(() => {
  for (const cleanup of cleanups.splice(0)) cleanup();
});

function setup(
  run: Parameters<typeof createScheduler>[0]["run"] = async () => {},
) {
  const jobs: Array<FakeSchedule> = [];
  const errors: Array<string> = [];
  const createSchedule: ScheduleFactory = (pattern, callback) => {
    const validation = new Cron(pattern, {
      paused: true,
      mode: "5-or-6-parts",
    });
    validation.stop();
    const job = { run: callback, stopped: false, resumed: false };
    jobs.push(job);
    return {
      stop: () => {
        job.stopped = true;
      },
      resume: () => {
        job.resumed = true;
      },
    };
  };
  const scheduler = createScheduler({
    run,
    onError: (message) => errors.push(message),
    createSchedule,
  });
  cleanups.push(scheduler.stop);
  return { scheduler, jobs, errors };
}

describe("worker schedules", () => {
  test("real Croner accepts five/six fields and schedules enabled jobs only", () => {
    const scheduler = createScheduler({
      run: async () => {},
      onError: () => {},
    });
    cleanups.push(scheduler.stop);
    scheduler.replace([
      automation({ jobName: "five" }),
      automation({ jobName: "six", schedule: "0 0 * * * *" }),
      automation({
        jobName: "disabled",
        enabled: false,
        schedule: "invalid",
        monitor: true,
      }),
    ]);
    expect(scheduler.names()).toEqual(["five", "six"]);
    scheduler.stop();
    expect(scheduler.names()).toEqual([]);
  });

  test("invalid replacements dispose candidates and preserve old schedules", () => {
    const { scheduler, jobs } = setup();
    scheduler.replace([automation()]);
    expect(() =>
      scheduler.replace([
        automation({ jobName: "candidate" }),
        automation({ jobName: "invalid", schedule: "0 0 0 * * * 2026" }),
      ]),
    ).toThrow();
    expect(scheduler.names()).toEqual(["example"]);
    expect(jobs[0].stopped).toBe(false);
    expect(jobs[1]).toMatchObject({ stopped: true, resumed: false });
  });

  test("duplicates including disabled jobs and enabled monitors reject the batch", () => {
    const { scheduler, jobs } = setup();
    scheduler.replace([automation()]);
    expect(() =>
      scheduler.replace([automation(), automation({ enabled: false })]),
    ).toThrow("Duplicate jobName");
    expect(() => scheduler.replace([automation({ monitor: true })])).toThrow(
      "not supported",
    );
    expect(jobs[0].stopped).toBe(false);
  });

  test("overlap protection survives reload and removal/readdition", async () => {
    const pending = deferred();
    let count = 0;
    const { scheduler, jobs } = setup(async () => {
      count += 1;
      await pending.promise;
    });
    scheduler.replace([automation()]);
    const first = jobs[0].run();
    scheduler.replace([]);
    scheduler.replace([automation({ userPrompt: "Changed" })]);
    await jobs[1].run();
    expect(count).toBe(1);
    pending.resolve();
    await first;
    await jobs[1].run();
    expect(count).toBe(2);
  });

  test("overlap is opt-in and a later protected reload waits for all runs", async () => {
    const pending = deferred();
    let count = 0;
    const { scheduler, jobs } = setup(async () => {
      count += 1;
      await pending.promise;
    });
    scheduler.replace([automation({ canOverlap: true })]);
    const first = jobs[0].run();
    const second = jobs[0].run();
    scheduler.replace([automation()]);
    await jobs[1].run();
    expect(count).toBe(2);
    pending.resolve();
    await Promise.all([first, second]);
    await jobs[1].run();
    expect(count).toBe(3);
  });

  test("failure releases guard and stopped schedulers never launch new work", async () => {
    const { scheduler, jobs, errors } = setup(async () => {
      throw new Error("failed");
    });
    scheduler.replace([automation()]);
    await jobs[0].run();
    await jobs[0].run();
    expect(errors).toHaveLength(2);
    scheduler.stop();
    scheduler.replace([automation()]);
    await jobs[0].run();
    expect(errors).toHaveLength(2);
    expect(scheduler.names()).toEqual([]);
  });
});
