defmodule WebApp.Messages.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "messages" do
    field(:timestamp, :utc_datetime_usec)
    field(:sender_type, :string)
    field(:sender_id, :binary_id)
    field(:kind, :string)
    field(:content, :string)
    field(:sent_status, :string, default: "pending")
    field(:receiver_bot_id, :binary_id)
    timestamps(type: :utc_datetime)
  end

  def changeset(message, attributes) do
    message
    |> cast(attributes, [
      :timestamp,
      :sender_type,
      :sender_id,
      :receiver_bot_id,
      :kind,
      :content,
      :sent_status
    ])
    |> validate_required([
      :timestamp,
      :sender_type,
      :receiver_bot_id,
      :kind,
      :content,
      :sent_status
    ])
    |> validate_inclusion(:sender_type, ["bot", "automation"])
    |> validate_inclusion(:sent_status, ["pending", "processing", "sent", "failed"])
    |> foreign_key_constraint(:receiver_bot_id, name: nil)
  end
end
