import { homedir } from "node:os";
import { join } from "node:path";

export const storagePath = (): string => {
  const configPath = process.env.MATATO_PI_CONFIG;
  if (configPath === undefined) return join(homedir(), ".config", "matato-pi");
  if (configPath === "~") return homedir();
  if (configPath.startsWith("~/")) return join(homedir(), configPath.slice(2));
  return configPath;
};

export const databasePath = (): string =>
  join(storagePath(), "matato-pi.sqlite3");
