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

type DiscordUser = {
  id: string;
  username: string;
  global_name: string | null;
  bot: boolean;
};

type DiscordMessage = {
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

const verifyGuildChannel = async (
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
): Promise<Array<DiscordMessage>> => {
  const configuration = resolveDiscordConfiguration();
  await verifyGuildChannel(configuration, channelId);
  const messageLimit = resolveMessageLimit(limit);
  return requestDiscord<Array<DiscordMessage>>(
    configuration,
    `/channels/${channelId}/messages?limit=${messageLimit}`,
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
    { method: "POST", body: JSON.stringify({ content }) },
  );
};

export const replyToMessage = async ({
  channelId,
  messageId,
  content,
}: ReplyToMessageInput): Promise<DiscordMessage> => {
  const configuration = resolveDiscordConfiguration();
  await verifyGuildChannel(configuration, channelId);
  if (!content.trim()) throw new Error("content is required");

  return requestDiscord<DiscordMessage>(
    configuration,
    `/channels/${channelId}/messages`,
    {
      method: "POST",
      body: JSON.stringify({
        content,
        message_reference: { message_id: messageId, fail_if_not_exists: true },
      }),
    },
  );
};
