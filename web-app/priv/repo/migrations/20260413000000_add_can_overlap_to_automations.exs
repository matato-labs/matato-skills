defmodule WebApp.Repo.Migrations.AddCanOverlapToAutomations do
  use Ecto.Migration

  def change do
    alter table(:automations) do
      add :can_overlap, :boolean, null: false, default: false
    end
  end
end
