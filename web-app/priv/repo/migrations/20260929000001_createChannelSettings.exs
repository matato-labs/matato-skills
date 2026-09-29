defmodule WebApp.Repo.Migrations.CreateChannelSettings do
  use Ecto.Migration

  def up do
    create table(:channel_settings, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:enabled, :boolean, null: false, default: false)
      timestamps(type: :utc_datetime)
    end

    # Retire old channel skill automations so they cannot poll after upgrade.
    # Only exact skill jobs are removed; recorded remote sessions/transcripts and
    # all other automations remain untouched. Rollback cannot restore removed jobs.
    execute(
      "DELETE FROM automations WHERE use_skill = 1 AND job_name IN ('telegram-inbox', 'discord')"
    )
  end

  def down do
    drop(table(:channel_settings))
  end
end
