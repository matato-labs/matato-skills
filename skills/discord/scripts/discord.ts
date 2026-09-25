const discordApiBaseUrl = "https://discord.com/api/v10";
const maximumMessageLimit = 100;

type DiscordConfiguration = {
  botToken: string;
  guildId: string;
  allowedChannelIds: Set<string>;
};

type DiscordChannel = {
  id: string;
  guild_id?: string;
  type: number;
  name?: string;
  parent_id?: string | null;
};

export type DiscordUser = {
  id: string;
  username: string;
  global_name: string | null;
  bot: boolean;
};

export type DiscordMessage = {
  id: string;
  channel_id: string;
  content: string;
  author: DiscordUser;
  timestamp: string;
};

type SendMessageInput = {
  channelId: string;
  content: string;
};

type ReplyToMessageInput = SendMessageInput & {
  messageId: string;
};

const requiredEnvironmentValue = (name: string): string => {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
};

export const resolveDiscordConfiguration = (): DiscordConfiguration => {
  const allowedChannelIds = new Set(
    requiredEnvironmentValue("DISCORD_CHANNEL_IDS")
      .split(",")
      .map((channelId) => channelId.trim())
      .filter(Boolean),
  );
  if (allowedChannelIds.size === 0)
    throw new Error("DISCORD_CHANNEL_IDS must contain a channel ID");

  return {
    botToken: requiredEnvironmentValue("DISCORD_BOT_TOKEN"),
    guildId: requiredEnvironmentValue("DISCORD_GUILD_ID"),
    allowedChannelIds,
  };
};

const requestDiscord = async <ResponseBody>(
  configuration: DiscordConfiguration,
  path: string,
  init: RequestInit = {},
): Promise<ResponseBody> => {
  const response = await fetch(`${discordApiBaseUrl}${path}`, {
    ...init,
    headers: {
      Authorization: `Bot ${configuration.botToken}`,
      ...(init.body ? { "Content-Type": "application/json" } : {}),
    },
  });
  if (!response.ok)
    throw new Error(
      `Discord API request failed with status ${response.status}`,
    );

  return response.json() as Promise<ResponseBody>;
};

const requireAllowedChannel = (
  configuration: DiscordConfiguration,
  channelId: string,
): void => {
  if (!configuration.allowedChannelIds.has(channelId))
    throw new Error(`Channel ${channelId} is not allowlisted`);
};

export const verifyGuildChannel = async (
  configuration: DiscordConfiguration,
  channelId: string,
): Promise<DiscordChannel> => {
  requireAllowedChannel(configuration, channelId);
  const channel = await requestDiscord<DiscordChannel>(
    configuration,
    `/channels/${channelId}`,
  );
  if (channel.guild_id !== configuration.guildId)
    throw new Error(`Channel ${channelId} is not in the configured guild`);

  return channel;
};

const resolveMessageLimit = (limit: number): number =>
  Math.min(Math.max(1, Math.floor(limit)), maximumMessageLimit);

export const getBotIdentity = async (): Promise<DiscordUser> =>
  requestDiscord<DiscordUser>(resolveDiscordConfiguration(), "/users/@me");

export const listAllowedChannels = async (): Promise<Array<DiscordChannel>> => {
  const configuration = resolveDiscordConfiguration();
  const channels = await requestDiscord<Array<DiscordChannel>>(
    configuration,
    `/guilds/${configuration.guildId}/channels`,
  );
  return channels.filter((channel) =>
    configuration.allowedChannelIds.has(channel.id),
  );
};

export const readMessages = async (
  channelId: string,
  limit = 25,
  before?: string,
): Promise<Array<DiscordMessage>> => {
  const configuration = resolveDiscordConfiguration();
  await verifyGuildChannel(configuration, channelId);
  const query = new URLSearchParams({
    limit: String(resolveMessageLimit(limit)),
  });
  if (before) query.set("before", before);
  return requestDiscord<Array<DiscordMessage>>(
    configuration,
    `/channels/${channelId}/messages?${query}`,
  );
};

// Walk backwards from the newest page until the saved cursor is reached.
// Never advance a cursor if the bounded scan cannot reach it.
export const readNewMessages = async (
  channelId: string,
  after: string,
  maximumPages = 10,
): Promise<Array<DiscordMessage>> => {
  const messages: Array<DiscordMessage> = [];
  let before: string | undefined;
  for (let page = 0; page < maximumPages; page += 1) {
    const batch = await readMessages(channelId, maximumMessageLimit, before);
    if (batch.length === 0) break;
    messages.push(
      ...batch.filter((message) => BigInt(message.id) > BigInt(after)),
    );
    if (
      batch.some((message) => BigInt(message.id) <= BigInt(after)) ||
      batch.length < maximumMessageLimit
    )
      break;
    before = batch[batch.length - 1].id;
    if (page === maximumPages - 1)
      throw new Error(
        `Discord channel ${channelId} exceeded the polling page limit`,
      );
  }
  return messages.sort((left, right) =>
    BigInt(left.id) < BigInt(right.id)
      ? -1
      : BigInt(left.id) > BigInt(right.id)
        ? 1
        : 0,
  );
};

export const sendMessage = async ({
  channelId,
  content,
}: SendMessageInput): Promise<DiscordMessage> => {
  const configuration = resolveDiscordConfiguration();
  await verifyGuildChannel(configuration, channelId);
  if (!content.trim()) throw new Error("content is required");

  return requestDiscord<DiscordMessage>(
    configuration,
    `/channels/${channelId}/messages`,
    {
      method: "POST",
      body: JSON.stringify({ content, allowed_mentions: { parse: [] } }),
    },
  );
};

export const replyToMessage = async ({
  channelId,
  messageId,
  content,
}: ReplyToMessageInput): Promise<DiscordMessage> => {
  if (!messageId.trim()) throw new Error("messageId is required");
  if (!content.trim()) throw new Error("content is required");
  const configuration = resolveDiscordConfiguration();
  await verifyGuildChannel(configuration, channelId);

  return requestDiscord<DiscordMessage>(
    configuration,
    `/channels/${channelId}/messages`,
    {
      method: "POST",
      body: JSON.stringify({
        content,
        allowed_mentions: { parse: [] },
        message_reference: {
          message_id: messageId,
          channel_id: channelId,
          fail_if_not_exists: true,
        },
      }),
    },
  );
};
