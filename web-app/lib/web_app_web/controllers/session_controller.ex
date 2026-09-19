defmodule WebAppWeb.SessionController do
  use WebAppWeb, :controller

  alias WebApp.Sessions

  def create(conn, params) do
    case Sessions.register(params) do
      {:ok, session} ->
        conn |> put_status(:created) |> json(%{session: session})

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {message, _options} -> message end)
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors})

      {:error, message} when is_binary(message) ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: message})
    end
  end
end
