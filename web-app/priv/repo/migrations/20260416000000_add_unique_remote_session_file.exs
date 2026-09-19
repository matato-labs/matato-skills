defmodule WebApp.Repo.Migrations.AddUniqueRemoteSessionFile do
  use Ecto.Migration

  def change do
    create unique_index(:remote_sessions, [:session_file])
  end
end
