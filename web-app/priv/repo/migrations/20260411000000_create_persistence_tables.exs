defmodule WebApp.Repo.Migrations.CreatePersistenceTables do
  use Ecto.Migration

  def change do
    create table(:remote_sessions, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :project_path, :string, null: false
      add :relative_project, :string, null: false
      add :session_file, :string
      add :pi_session_id, :string
      add :source, :string, null: false, default: "web"
      add :status, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:remote_sessions, [:updated_at])
    create index(:remote_sessions, [:status])

    create table(:automations) do
      add :job_name, :string, null: false
      add :enabled, :boolean, null: false, default: true
      add :schedule, :string, null: false
      add :user_prompt, :text, null: false
      add :daily_session, :boolean, null: false, default: false
      add :model, :string, null: false
      add :thinking_level, :string, null: false
      add :can_launch_sub_agents, :boolean, null: false, default: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:automations, [:job_name])
  end
end
