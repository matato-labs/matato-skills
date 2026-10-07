import { Cron } from "croner";
import type { Automation } from "../src/automation.ts";

export type Schedule = { stop: () => void; resume: () => void };
export type ScheduleFactory = (
  pattern: string,
  run: () => Promise<void>,
) => Schedule;
export type SchedulerOptions = {
  run: (automation: Automation) => Promise<void>;
  onError: (message: string) => void;
  createSchedule?: ScheduleFactory;
};

const createSchedule: ScheduleFactory = (pattern, run) =>
  new Cron(pattern, { paused: true, mode: "5-or-6-parts" }, run);

export function createScheduler(options: SchedulerOptions): {
  replace: (automations: Array<Automation>) => void;
  stop: () => void;
  names: () => Array<string>;
} {
  let schedules = new Map<string, Schedule>();
  const activeJobs = new Map<string, number>();
  let stopped = false;
  const run = async (automation: Automation): Promise<void> => {
    if (stopped) return;
    const name = automation.jobName;
    if (!automation.canOverlap && activeJobs.has(name)) return;
    activeJobs.set(name, (activeJobs.get(name) ?? 0) + 1);
    try {
      await options.run(automation);
    } catch (error) {
      options.onError(`Job failed: ${name}: ${String(error)}`);
    } finally {
      const remaining = (activeJobs.get(name) ?? 1) - 1;
      if (remaining) activeJobs.set(name, remaining);
      else activeJobs.delete(name);
    }
  };
  return {
    replace(automations) {
      if (stopped) return;
      const names = new Set<string>();
      const nextSchedules = new Map<string, Schedule>();
      try {
        for (const automation of automations) {
          if (names.has(automation.jobName))
            throw new Error(`Duplicate jobName: ${automation.jobName}`);
          names.add(automation.jobName);
          if (!automation.enabled) continue;
          if (automation.monitor)
            throw new Error(
              `Job ${automation.jobName}: monitor is not supported by the standalone worker`,
            );
          nextSchedules.set(
            automation.jobName,
            (options.createSchedule ?? createSchedule)(
              automation.schedule,
              () => run(automation),
            ),
          );
        }
      } catch (error) {
        for (const schedule of nextSchedules.values()) schedule.stop();
        throw error;
      }
      for (const schedule of schedules.values()) schedule.stop();
      schedules = nextSchedules;
      for (const schedule of schedules.values()) schedule.resume();
    },
    stop() {
      stopped = true;
      for (const schedule of schedules.values()) schedule.stop();
      schedules.clear();
    },
    names: () => [...schedules.keys()],
  };
}
