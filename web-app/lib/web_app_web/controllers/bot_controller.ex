defmodule WebAppWeb.BotController do
  use WebAppWeb, :controller

  alias WebApp.Bots

  def index(conn, _params), do: json(conn, %{bots: Enum.map(Bots.list(), &data/1)})

  def show(conn, %{"id" => id}) do
    case Bots.get(id) do
      nil -> not_found(conn)
      bot -> json(conn, %{bot: data(bot)})
    end
  end

  def create(conn, params) do
    case Bots.create(params) do
      {:ok, bot} ->
        conn |> put_status(:created) |> json(%{bot: data(bot)})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_error(reason)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Bots.delete(id) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        not_found(conn)

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_error(reason)})
    end
  end

  defp data(bot),
    do:
      Map.take(bot, [
        :id,
        :name,
        :role,
        :description,
        :chat_remote_session_id,
        :background_remote_session_id
      ])

  defp format_error(%Ecto.Changeset{} = changeset),
    do: Ecto.Changeset.traverse_errors(changeset, fn {message, _options} -> message end)

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
  defp not_found(conn), do: conn |> put_status(:not_found) |> json(%{error: "Bot not found"})
end
