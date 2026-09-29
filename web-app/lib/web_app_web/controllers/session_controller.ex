defmodule WebAppWeb.SessionController do
  use WebAppWeb, :controller

  alias WebApp.Sessions

  def create(conn, params) do
    result =
      if Map.has_key?(params, "relative_project"),
        do: Sessions.register(params),
        else: create_general()

    case result do
      {:ok, session} ->
        conn |> put_status(:created) |> json(%{session: session})

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {message, _options} -> message end)
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors})

      {:error, message} when is_binary(message) ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: message})
    end
  end

  defp create_general do
    with {:ok, id} <- Sessions.create_general(), do: {:ok, Sessions.get(id)}
  end
end
