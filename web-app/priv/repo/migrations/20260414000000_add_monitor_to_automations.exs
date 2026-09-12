defmodule WebApp.Repo.Migrations.AddMonitorToAutomations do
  use Ecto.Migration

  def up do
    if monitor_column?(), do: :ok, else: execute("ALTER TABLE automations ADD COLUMN monitor BOOLEAN NOT NULL DEFAULT FALSE")
  end

  def down do
    if monitor_column?(), do: execute("ALTER TABLE automations DROP COLUMN monitor"), else: :ok
  end

  defp monitor_column? do
    %{rows: rows} = repo().query!("PRAGMA table_info(automations)")
    Enum.any?(rows, fn [_id, name | _details] -> name == "monitor" end)
  end
end
