defmodule WebApp.Messages do
  import Ecto.Query

  alias WebApp.{Bots, Repo}
  alias WebApp.Messages.Message

  def create(attributes) do
    attributes = Map.put_new(attributes, :timestamp, DateTime.utc_now())
    changeset = Message.changeset(%Message{}, attributes)

    with :ok <- validate_receiver(changeset) do
      changeset |> Repo.insert() |> notify_result()
    end
  end

  def create_automation_result(nil, _content), do: :ok

  def create_automation_result(bot_id, content) do
    create(%{
      receiver_bot_id: bot_id,
      sender_type: "automation",
      kind: "result",
      content: content
    })
  end

  def list_for_bot(bot_id) do
    Repo.all(
      from(message in Message,
        where: message.receiver_bot_id == ^bot_id,
        order_by: [asc: message.timestamp, asc: message.id]
      )
    )
  end

  def claim_pending(excluded_ids \\ []) do
    query =
      from(message in Message,
        where: message.sent_status == "pending",
        order_by: [asc: message.timestamp, asc: message.id],
        limit: 1
      )

    query =
      if excluded_ids == [],
        do: query,
        else: from(message in query, where: message.id not in ^excluded_ids)

    case Repo.one(query) do
      nil ->
        nil

      message ->
        {count, _} =
          Repo.update_all(
            from(candidate in Message,
              where: candidate.id == ^message.id and candidate.sent_status == "pending"
            ),
            set: [sent_status: "processing", updated_at: DateTime.utc_now()]
          )

        if count == 1, do: Repo.get(Message, message.id), else: claim_pending(excluded_ids)
    end
  end

  def requeue(message) do
    Repo.update_all(from(candidate in Message, where: candidate.id == ^message.id),
      set: [sent_status: "pending", updated_at: DateTime.utc_now()]
    )

    notify(message.receiver_bot_id)
    :ok
  end

  def finish(message, status) when status in ["sent", "failed"] do
    {_, _} =
      Repo.update_all(from(candidate in Message, where: candidate.id == ^message.id),
        set: [sent_status: status, updated_at: DateTime.utc_now()]
      )

    notify(message.receiver_bot_id)
    :ok
  end

  def reset_processing do
    Repo.update_all(from(message in Message, where: message.sent_status == "processing"),
      set: [sent_status: "pending", updated_at: DateTime.utc_now()]
    )
  end

  def subscribe(bot_id), do: Phoenix.PubSub.subscribe(WebApp.PubSub, topic(bot_id))
  def subscribe_all, do: Phoenix.PubSub.subscribe(WebApp.PubSub, "messages")

  defp validate_receiver(changeset) do
    if Bots.get(Ecto.Changeset.get_field(changeset, :receiver_bot_id)),
      do: :ok,
      else: {:error, Ecto.Changeset.add_error(changeset, :receiver_bot_id, "does not exist")}
  end

  defp notify_result({:ok, message}) do
    notify(message.receiver_bot_id)
    {:ok, message}
  end

  defp notify_result(error), do: error

  defp notify(bot_id) do
    Phoenix.PubSub.broadcast(WebApp.PubSub, topic(bot_id), {:message_changed, bot_id})
    Phoenix.PubSub.broadcast(WebApp.PubSub, "messages", :changed)
  end

  defp topic(bot_id), do: "messages:#{bot_id}"
end
