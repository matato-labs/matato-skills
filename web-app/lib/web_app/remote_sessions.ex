defmodule WebApp.RemoteSessions do
  import Ecto.Query

  alias WebApp.Repo
  alias WebApp.RemoteSessions.RemoteSession

  def list,
    do:
      Repo.all(from(session in RemoteSession, order_by: [desc: session.updated_at]))
      |> Enum.map(&to_metadata/1)

  def get(id), do: Repo.get(RemoteSession, id) |> to_metadata()

  def create(attributes) do
    %RemoteSession{}
    |> RemoteSession.changeset(attributes)
    |> Repo.insert()
    |> result()
  end

  def update(id, attributes) do
    with %RemoteSession{} = session <- Repo.get(RemoteSession, id),
         {:ok, session} <- session |> RemoteSession.changeset(attributes) |> Repo.update() do
      {:ok, to_metadata(session)}
    else
      nil -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def delete(id) do
    case Repo.get(RemoteSession, id) do
      nil ->
        {:error, :not_found}

      session ->
        Repo.delete(session)
        |> case do
          {:ok, _session} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  def mark_interrupted do
    from(session in RemoteSession,
      where:
        session.status in ["starting", "working", "waiting_for_input", "retrying", "compacting"]
    )
    |> Repo.update_all(set: [status: "interrupted", updated_at: DateTime.utc_now()])
  end

  defp result({:ok, session}), do: {:ok, to_metadata(session)}
  defp result({:error, changeset}), do: {:error, changeset}
  defp to_metadata(nil), do: nil

  defp to_metadata(session) do
    %{
      "id" => session.id,
      "name" => session.name,
      "project" => session.project_path,
      "relative_project" => session.relative_project,
      "session_file" => session.session_file,
      "pi_session_id" => session.pi_session_id,
      "source" => session.source,
      "status" => session.status,
      "created_at" => DateTime.to_iso8601(session.inserted_at),
      "updated_at" => DateTime.to_iso8601(session.updated_at)
    }
  end
end
