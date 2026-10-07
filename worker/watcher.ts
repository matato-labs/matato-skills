import {
  automationConfigPath,
  loadAutomationConfig,
} from "../src/automationConfig.ts";
import type { Automation, AutomationConfig } from "../src/automation.ts";

export type WatcherOptions = {
  replace: (automations: Array<Automation>) => void;
  onReload: () => void;
  onError: (message: string) => void;
  configPath?: string;
  load?: () => Promise<AutomationConfig>;
  pollMs?: number;
};

export function createWatcher(options: WatcherOptions): {
  start: () => Promise<void>;
  poll: () => Promise<void>;
  stop: () => void;
} {
  const path = options.configPath ?? automationConfigPath();
  const load = options.load ?? (() => loadAutomationConfig(path));
  let content: string | undefined;
  let lastError: string | undefined;
  let polling = false;
  let stopped = false;
  let interval: ReturnType<typeof setInterval> | undefined;
  const poll = async (): Promise<void> => {
    if (stopped || polling) return;
    polling = true;
    try {
      const config = await load();
      if (stopped) return;
      const nextContent = JSON.stringify(config);
      if (nextContent === content) {
        lastError = undefined;
        return;
      }
      options.replace(config.automations);
      content = nextContent;
      lastError = undefined;
      options.onReload();
    } catch (error) {
      if (stopped) return;
      const message = `Could not reload ${path}: ${String(error)}`;
      if (message !== lastError) options.onError(message);
      lastError = message;
    } finally {
      polling = false;
    }
  };
  return {
    async start() {
      if (stopped || interval) return;
      // Keep this referenced: an empty/missing config must not exit the worker.
      interval = setInterval(() => void poll(), options.pollMs ?? 5_000);
      await poll();
    },
    poll,
    stop() {
      stopped = true;
      if (interval) clearInterval(interval);
      interval = undefined;
    },
  };
}
