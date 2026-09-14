defmodule WebApp.Bots do
  import Ecto.Query

  alias WebApp.{RemoteRegistry, Repo}
  alias WebApp.Bots.Bot

  def list, do: Repo.all(from(bot in Bot, order_by: [asc: bot.inserted_at]))
  def get(nil), do: nil
  def get(id), do: Repo.get(Bot, id)
  def name(id), do: with(%Bot{name: name} <- get(id), do: name)

  def identity(id) do
    with %Bot{} = bot <- get(id), do: identity_for(bot)
  end

  def identity_for_session(session_id) do
    with %Bot{} = bot <-
           Repo.one(
             from(bot in Bot,
               where:
                 bot.chat_remote_session_id == ^session_id or
                   bot.background_remote_session_id == ^session_id
             )
           ) do
      identity_for(bot)
    end
  end

  def create(attributes) do
    relative = "."
    name = Map.get(attributes, "name") || Map.get(attributes, :name)

    identity = identity_for(attributes)

    with {:ok, chat_id} <-
           RemoteRegistry.create(relative, %{name: name, source: "bot_chat", identity: identity}),
         {:ok, background_id} <-
           RemoteRegistry.create(relative, %{
             name: "#{name} background",
             source: "bot_background",
             identity: identity
           }),
         {:ok, bot} <- insert(attributes, chat_id, background_id) do
      notify()
      {:ok, bot}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def delete(id) do
    case get(id) do
      nil ->
        {:error, :not_found}

      bot ->
        :ok = RemoteRegistry.delete(bot.chat_remote_session_id)
        :ok = RemoteRegistry.delete(bot.background_remote_session_id)
        Repo.delete(bot)
        notify()
        :ok
    end
  end

  def subscribe, do: Phoenix.PubSub.subscribe(WebApp.PubSub, "bots")

  defp identity_for(%Bot{} = bot), do: "You are #{bot.name}, #{bot.role}. #{bot.description}"

  defp identity_for(attributes) do
    name = Map.get(attributes, "name") || Map.get(attributes, :name)
    role = Map.get(attributes, "role") || Map.get(attributes, :role)
    description = Map.get(attributes, "description") || Map.get(attributes, :description)
    "You are #{name}, #{role}. #{description}"
  end

  defp insert(attributes, chat_id, background_id) do
    %Bot{}
    |> Bot.changeset(%{
      name: Map.get(attributes, "name") || Map.get(attributes, :name),
      role: Map.get(attributes, "role") || Map.get(attributes, :role),
      description: Map.get(attributes, "description") || Map.get(attributes, :description),
      chat_remote_session_id: chat_id,
      background_remote_session_id: background_id
    })
    |> Repo.insert()
  end

  defp notify, do: Phoenix.PubSub.broadcast(WebApp.PubSub, "bots", :changed)
end
