import { homedir } from "node:os";
import { join } from "node:path";

export const storagePath = (): string => {
  const configPath = process.env.MATATO_SKILLS_CONFIG;
  if (configPath === undefined)
    return join(homedir(), ".config", "matato-skills");
  if (configPath === "~") return homedir();
  if (configPath.startsWith("~/")) return join(homedir(), configPath.slice(2));
  return configPath;
};

export const databasePath = (): string =>
  join(storagePath(), "matato-skills.sqlite3");
