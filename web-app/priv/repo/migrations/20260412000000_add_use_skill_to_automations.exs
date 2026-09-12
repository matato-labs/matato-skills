defmodule WebApp.Repo.Migrations.AddUseSkillToAutomations do
  use Ecto.Migration

  def change do
    alter table(:automations) do
      add :use_skill, :boolean, null: false, default: true
    end
  end
end
