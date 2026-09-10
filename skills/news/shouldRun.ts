import { mkdir } from "node:fs/promises";
import path from "node:path";

type NewsDigestState = {
  lastSentDate: string;
  sentItems: Array<NewsDigestStateItem>;
};

type NewsDigestStateItem = {
  url: string;
  sentOn: string;
};

type LocalDateTime = {
  date: string;
  hour: number;
  minute: number;
};

type NewsPreScriptResult =
  | {
      skip: true;
      reason: string;
      localDate: string;
    }
  | {
      localDate: string;
      localHour: number;
      localMinute: number;
      timezone: string;
      stateFile: string;
      lastSentDate: string;
      sentItemsCount: number;
    };

export const run = async (): Promise<NewsPreScriptResult> => {
  const storagePath = Bun.env.STORAGE_PATH;
  const timezone = Bun.env.TIMEZONE ?? "UTC";

  if (!storagePath) {
    throw new Error("STORAGE_PATH must be set");
  }

  const stateFile = path.join(storagePath, "agent", "newsDigest.json");
  const state = await readOrCreateState(stateFile);
  const localDateTime = getLocalDateTime(new Date(), timezone);

  if (localDateTime.hour < 12) {
    return {
      skip: true,
      reason: `Local time is before 12:00 in ${timezone}`,
      localDate: localDateTime.date,
    };
  }

  if (state.lastSentDate === localDateTime.date) {
    return {
      skip: true,
      reason: `News digest already sent for ${localDateTime.date}`,
      localDate: localDateTime.date,
    };
  }

  return {
    localDate: localDateTime.date,
    localHour: localDateTime.hour,
    localMinute: localDateTime.minute,
    timezone,
    stateFile,
    lastSentDate: state.lastSentDate,
    sentItemsCount: state.sentItems.length,
  };
};

async function readOrCreateState(filePath: string): Promise<NewsDigestState> {
  const file = Bun.file(filePath);

  if (await file.exists()) {
    return (await file.json()) as NewsDigestState;
  }

  const initialState: NewsDigestState = {
    lastSentDate: "",
    sentItems: [],
  };
  await mkdir(path.dirname(filePath), { recursive: true });
  await Bun.write(filePath, JSON.stringify(initialState, null, 2));
  return initialState;
}

function getLocalDateTime(date: Date, timezoneName: string): LocalDateTime {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezoneName,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(date);
  const values = Object.fromEntries(
    parts.map((part) => [part.type, part.value]),
  );
  const year = values.year ?? "";
  const month = values.month ?? "";
  const day = values.day ?? "";
  const hour = Number(values.hour ?? "0");
  const minute = Number(values.minute ?? "0");

  return {
    date: `${year}-${month}-${day}`,
    hour,
    minute,
  };
}
