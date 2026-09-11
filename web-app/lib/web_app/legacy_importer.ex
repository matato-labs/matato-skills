defmodule WebApp.LegacyImporter do
  require Logger

  alias WebApp.{Automation, RemoteSessions, Repo, Workspace}
  alias WebApp.RemoteSessions.RemoteSession

  def import do
    import_sessions(Application.fetch_env!(:web_app, :legacy_sessions_file))
    Automation.import(Application.fetch_env!(:web_app, :legacy_automations_file))
  end

  defp import_sessions(path) do
    if Repo.exists?(RemoteSession) do
      :ok
    else
      case File.read(path) do
        {:error, :enoent} ->
          :ok

        {:ok, body} ->
          import_session_json(path, body)

        {:error, reason} ->
          Logger.warning("Could not import remote sessions", reason: inspect(reason))
      end
    end
  end

  defp import_session_json(path, body) do
    with {:ok, sessions} when is_map(sessions) <- Jason.decode(body) do
      Enum.each(sessions, &import_session/1)
      backup(path)
    else
      _ -> Logger.warning("Ignoring invalid legacy remote session metadata", path: path)
    end
  end

  defp import_session(
         {_id, %{"id" => id, "relative_project" => relative, "status" => status} = metadata}
       ) do
    project = Workspace.resolve(relative)

    attributes = %{
      id: id,
      name: Map.get(metadata, "name", Path.basename(project)),
      project_path: project,
      relative_project: Path.relative_to(project, Workspace.root()),
      session_file: Map.get(metadata, "session_file"),
      pi_session_id: Map.get(metadata, "pi_session_id"),
      source: Map.get(metadata, "source", "web"),
      status: status
    }

    case RemoteSessions.create(attributes) do
      {:ok, _session} -> :ok
      {:error, _changeset} -> Logger.warning("Skipping invalid legacy remote session", id: id)
    end
  rescue
    error in [ArgumentError, File.Error] ->
      Logger.warning("Skipping invalid legacy remote session", reason: Exception.message(error))
  end

  defp import_session(_), do: Logger.warning("Skipping invalid legacy remote session")

  defp backup(path),
    do: File.rename(path, "#{path}.imported-#{DateTime.utc_now() |> DateTime.to_unix()}.json")
end
