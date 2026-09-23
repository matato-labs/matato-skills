import {
  getBotIdentity,
  readMessages,
  readNewMessages,
  resolveDiscordConfiguration,
  type DiscordMessage,
} from "./discord.ts";
import {
  clearPendingDiscordCheckpoint,
  readDiscordCheckpoint,
  writeDiscordCheckpoint,
  writePendingDiscordCheckpoint,
} from "./discordCheckpoint.ts";

const configuration = resolveDiscordConfiguration();
const previous = await readDiscordCheckpoint();
const next = { ...previous };
const incoming: Array<DiscordMessage> = [];
const bot = await getBotIdentity();

for (const channelId of configuration.allowedChannelIds) {
  const cursor = previous?.[channelId];
  if (!cursor) {
    // First poll for each channel starts at its latest message, not old history.
    const latest = await readMessages(channelId, 1);
    next[channelId] = latest[0]?.id ?? "0";
    continue;
  }
  const messages = await readNewMessages(channelId, cursor);
  if (messages.length === 0) continue;
  next[channelId] = messages[messages.length - 1].id;
  incoming.push(
    ...messages.filter(
      (message) =>
        !message.author.bot &&
        message.author.id !== bot.id &&
        message.content.trim(),
    ),
  );
}

if (incoming.length === 0) {
  await writeDiscordCheckpoint(next);
  await clearPendingDiscordCheckpoint();
  process.exit(0);
}

const output = incoming
  .sort((left, right) => left.timestamp.localeCompare(right.timestamp))
  .map((message) =>
    JSON.stringify({
      channelId: message.channel_id,
      messageId: message.id,
      authorId: message.author.id,
      timestamp: message.timestamp,
      content: message.content,
    }),
  )
  .join("\n");
if (Buffer.byteLength(output) > 50_000)
  throw new Error(
    "Discord inbox exceeds the automation context limit; poll more frequently",
  );
await writePendingDiscordCheckpoint(next);
console.log(output);
