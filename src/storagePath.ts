import { homedir } from "node:os";
import { join } from "node:path";

export const storagePath = (): string =>
  process.env.MATATO_PI_CONFIG ?? join(homedir(), ".config", "matato-pi");

export const automationConfigPath = (): string =>
  join(storagePath(), "automations", "config.json");
