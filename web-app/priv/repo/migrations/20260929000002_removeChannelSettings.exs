defmodule WebApp.Repo.Migrations.RemoveChannelSettings do
  use Ecto.Migration

  def up do
    drop_if_exists(table(:channel_settings))
  end

  def down do
    create table(:channel_settings, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:enabled, :boolean, null: false, default: false)
      timestamps(type: :utc_datetime)
    end
  end
end
