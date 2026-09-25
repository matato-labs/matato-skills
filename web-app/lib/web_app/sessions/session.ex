defmodule WebApp.Sessions.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "remote_sessions" do
    field(:name, :string)
    field(:project_path, :string)
    field(:relative_project, :string)
    field(:session_file, :string)
    field(:pi_session_id, :string)
    field(:source, :string, default: "web")
    field(:status, :string)
    field(:result, :string)
    timestamps(type: :utc_datetime)
  end

  def changeset(session, attributes) do
    session
    |> cast(attributes, [
      :id,
      :name,
      :project_path,
      :relative_project,
      :session_file,
      :pi_session_id,
      :source,
      :status,
      :result
    ])
    |> validate_required([:id, :name, :project_path, :relative_project, :source, :status])
  end
end
