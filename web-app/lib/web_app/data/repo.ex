defmodule WebApp.Data.Repo do
  use Ecto.Repo,
    otp_app: :web_app,
    adapter: Ecto.Adapters.SQLite3
end
