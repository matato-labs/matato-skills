import { homedir } from "node:os";
import { join } from "node:path";

export const storagePath = (): string =>
  process.env.MATATO_PI_STORAGE_PATH ??
  process.env.STORAGE_PATH ??
  join(homedir(), ".config", "matato-pi");
