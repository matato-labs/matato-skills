defmodule WebAppWeb.MessageController do
  use WebAppWeb, :controller

  alias WebApp.Messages

  def create(conn, params) do
    attributes = %{
      receiver_bot_id: params["receiver_bot_id"],
      sender_id: params["sender_id"],
      sender_type: "bot",
      kind: params["kind"],
      content: params["content"]
    }

    case Messages.create(attributes) do
      {:ok, message} ->
        conn |> put_status(:created) |> json(%{message: data(message)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_error(changeset)})
    end
  end

  defp data(message),
    do: Map.take(message, [:id, :sender_type, :sender_id, :receiver_bot_id, :kind, :sent_status])

  defp format_error(%Ecto.Changeset{} = changeset),
    do: Ecto.Changeset.traverse_errors(changeset, fn {message, _options} -> message end)
end
