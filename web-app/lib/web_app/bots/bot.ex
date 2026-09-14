defmodule WebApp.Bots.Bot do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "bots" do
    field(:name, :string)
    field(:role, :string)
    field(:description, :string)
    field(:chat_remote_session_id, :string)
    field(:background_remote_session_id, :string)
    timestamps(type: :utc_datetime)
  end

  def changeset(bot, attributes) do
    bot
    |> cast(attributes, [
      :name,
      :role,
      :description,
      :chat_remote_session_id,
      :background_remote_session_id
    ])
    |> validate_required([
      :name,
      :role,
      :description,
      :chat_remote_session_id,
      :background_remote_session_id
    ])
  end
end
