defmodule WebAppWeb.Auth do
  @moduledoc false

  def init(options), do: options

  def call(conn, _options) do
    case Application.get_env(:web_app, :basic_auth) do
      {username, password} ->
        Plug.BasicAuth.basic_auth(conn, username: username, password: password)

      nil ->
        conn
    end
  end
end
