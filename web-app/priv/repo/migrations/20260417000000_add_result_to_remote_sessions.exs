defmodule WebApp.Data.Repo.Migrations.AddResultToRemoteSessions do
  use Ecto.Migration

  def change, do: alter(table(:remote_sessions), do: add(:result, :text))
end
