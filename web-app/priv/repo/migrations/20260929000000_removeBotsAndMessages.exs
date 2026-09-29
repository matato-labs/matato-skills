defmodule WebApp.Repo.Migrations.RemoveBotsAndMessages do
  use Ecto.Migration

  def up do
    drop(index(:automations, [:bot_id]))

    alter table(:automations) do
      remove(:bot_id)
    end

    drop(table(:messages))
    drop(table(:bots))
  end

  def down do
    create table(:bots, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:name, :string, null: false)
      add(:role, :string, null: false)
      add(:description, :text, null: false)
      add(:chat_remote_session_id, :string, null: false)
      add(:background_remote_session_id, :string, null: false)
      timestamps(type: :utc_datetime)
    end

    create(unique_index(:bots, [:chat_remote_session_id]))
    create(unique_index(:bots, [:background_remote_session_id]))

    create table(:messages, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:timestamp, :utc_datetime_usec, null: false)
      add(:sender_type, :string, null: false)
      add(:sender_id, :binary_id)

      add(:receiver_bot_id, references(:bots, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:kind, :string, null: false)
      add(:content, :text, null: false)
      add(:sent_status, :string, null: false, default: "pending")
      timestamps(type: :utc_datetime)
    end

    create(index(:messages, [:receiver_bot_id, :timestamp, :id]))
    create(index(:messages, [:sent_status]))

    alter table(:automations) do
      add(:bot_id, references(:bots, type: :binary_id, on_delete: :nilify_all))
    end

    create(index(:automations, [:bot_id]))
  end
end
