import {
  getBotIdentity,
  listAllowedChannels,
  readMessages,
  replyToMessage,
  sendMessage,
} from "./discord.ts";

type CliOptions = {
  command: string;
  values: Map<string, string | true>;
};

const readOptions = (argumentsList: Array<string>): CliOptions => {
  const [command, ...optionArguments] = argumentsList;
  if (!command) throw new Error("A command is required");

  const values = new Map<string, string | true>();
  for (let index = 0; index < optionArguments.length; index += 1) {
    const option = optionArguments[index];
    if (!option.startsWith("--"))
      throw new Error(`Unexpected argument ${option}`);

    const name = option.slice(2);
    if (name === "confirm") {
      values.set(name, true);
      continue;
    }

    const value = optionArguments[index + 1];
    if (!value || value.startsWith("--"))
      throw new Error(`--${name} requires a value`);

    values.set(name, value);
    index += 1;
  }

  return { command, values };
};

const requiredValue = (options: CliOptions, name: string): string => {
  const value = options.values.get(name);
  if (!value || value === true) throw new Error(`--${name} is required`);
  return value;
};

const readLimit = (options: CliOptions): number => {
  const value = options.values.get("limit");
  if (!value) return 25;
  if (value === true) throw new Error("--limit requires a value");

  const limit = Number(value);
  if (!Number.isInteger(limit) || limit < 1)
    throw new Error("--limit must be a positive integer");

  return limit;
};

const printConfirmation = (
  channelId: string,
  content: string,
  messageId?: string,
): void => {
  console.log("Write not sent: confirmation is required.");
  console.log(`Destination: Discord channel ${channelId}`);
  if (messageId) console.log(`Replying to: Discord message ${messageId}`);
  console.log(`Content:\n${content}`);
  console.log("After the user confirms, rerun this command with --confirm.");
};

const run = async (): Promise<void> => {
  const options = readOptions(process.argv.slice(2));

  switch (options.command) {
    case "identity":
      console.log(JSON.stringify(await getBotIdentity(), null, 2));
      return;
    case "list":
      console.log(JSON.stringify(await listAllowedChannels(), null, 2));
      return;
    case "read": {
      const channelId = requiredValue(options, "channelId");
      console.log(
        JSON.stringify(
          await readMessages(channelId, readLimit(options)),
          null,
          2,
        ),
      );
      return;
    }
    case "send": {
      const channelId = requiredValue(options, "channelId");
      const content = requiredValue(options, "content");
      if (options.values.get("confirm") !== true) {
        printConfirmation(channelId, content);
        return;
      }

      console.log(
        JSON.stringify(await sendMessage({ channelId, content }), null, 2),
      );
      return;
    }
    case "reply": {
      const channelId = requiredValue(options, "channelId");
      const messageId = requiredValue(options, "messageId");
      const content = requiredValue(options, "content");
      if (options.values.get("confirm") !== true) {
        printConfirmation(channelId, content, messageId);
        return;
      }

      console.log(
        JSON.stringify(
          await replyToMessage({ channelId, messageId, content }),
          null,
          2,
        ),
      );
      return;
    }
    default:
      throw new Error(`Unknown command ${options.command}`);
  }
};

await run();
