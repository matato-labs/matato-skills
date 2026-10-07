import { automationConfigPath } from "../src/automationConfig.ts";
import { runAutomation } from "./runner.ts";
import { createScheduler } from "./scheduler.ts";
import { createWatcher } from "./watcher.ts";

const log = (message: string): void =>
  console.log(`[matato-pi-worker] ${message}`);
const onError = (message: string): void =>
  console.error(`[matato-pi-worker] ${message}`);
const controller = new AbortController();
const scheduler = createScheduler({
  async run(automation) {
    const result = await runAutomation(automation, {
      signal: controller.signal,
    });
    log(`Job ${result}: ${automation.jobName}`);
  },
  onError,
});
const watcher = createWatcher({
  replace: scheduler.replace,
  onReload: () => log(`Scheduled: ${scheduler.names().join(", ") || "none"}`),
  onError,
});

function shutdown(): void {
  if (controller.signal.aborted) return;
  watcher.stop();
  scheduler.stop();
  controller.abort();
  log("Stopped");
}

process.once("SIGINT", shutdown);
process.once("SIGTERM", shutdown);
log(`Watching ${automationConfigPath()}`);
await watcher.start();
