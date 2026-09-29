defmodule WebApp.Sessions.Store do
  import Ecto.Query

  alias WebApp.Data.Repo
  alias WebApp.Sessions.{Session, Workspace}

  def list,
    do:
      Repo.all(from(session in Session, order_by: [desc: session.updated_at]))
      |> Enum.map(&to_metadata/1)

  def get(id), do: Repo.get(Session, id) |> to_metadata()
  def exists?, do: Repo.exists?(Session)

  def validate_metadata(metadata) do
    with true <- valid_id?(metadata["id"]),
         {:ok, project} <- metadata_project(metadata),
         {:ok, session_file} <-
           validate_session_file(metadata["session_file"], metadata["source"]) do
      {:ok, metadata |> Map.put("project", project) |> Map.put("session_file", session_file)}
    else
      _ -> {:error, "Invalid session metadata"}
    end
  rescue
    error in [ArgumentError, File.Error] -> {:error, Exception.message(error)}
  end

  def config_root! do
    path = Application.fetch_env!(:web_app, :automation_storage_path) |> Path.expand()
    File.mkdir_p!(path)

    case Workspace.canonical(path) do
      {:ok, root} -> root
      {:error, reason} -> raise File.Error, reason: reason, action: "resolve", path: path
    end
  end

  defp metadata_project(%{"source" => "general", "relative_project" => ".", "project" => stored}) do
    root = config_root!()
    if stored == root, do: {:ok, root}, else: {:error, :invalid_project}
  end

  defp metadata_project(%{"source" => "general"}), do: {:error, :invalid_project}

  defp metadata_project(%{
         "source" => "automation",
         "relative_project" => ".",
         "project" => stored
       }) do
    root = config_root!()
    if stored == root, do: {:ok, root}, else: workspace_project(".", stored)
  end

  defp metadata_project(%{"relative_project" => relative, "project" => stored})
       when is_binary(relative), do: workspace_project(relative, stored)

  defp metadata_project(_metadata), do: {:error, :invalid_project}

  defp workspace_project(relative, stored)
       when is_binary(relative) do
    project = Workspace.resolve(relative)
    if stored == project, do: {:ok, project}, else: {:error, :invalid_project}
  end

  def create(attributes) do
    %Session{}
    |> Session.changeset(attributes)
    |> Repo.insert()
    |> result()
  end

  def register(attributes) do
    with {:ok, project, relative} <- registration_project(attributes["relative_project"]),
         {:ok, session_file} <- registration_session_file(attributes["session_file"]) do
      upsert_registered(%{
        name: registration_name(attributes["name"], project),
        project_path: project,
        relative_project: relative,
        session_file: session_file,
        pi_session_id: attributes["pi_session_id"]
      })
    end
  end

  def update(id, attributes) do
    with %Session{} = session <- Repo.get(Session, id),
         {:ok, session} <- session |> Session.changeset(attributes) |> Repo.update() do
      {:ok, to_metadata(session)}
    else
      nil -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def delete(id) do
    case Repo.get(Session, id) do
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
    from(session in Session,
      where:
        session.status in ["starting", "working", "waiting_for_input", "retrying", "compacting"]
    )
    |> Repo.update_all(set: [status: "interrupted", updated_at: DateTime.utc_now()])
  end

  def validate_session_file(path), do: validate_session_file(path, "web")
  def validate_session_file(nil, _source), do: {:ok, nil}

  def validate_session_file(path, source) when is_binary(path) do
    root = Application.fetch_env!(:web_app, :session_dir) |> Path.expand()

    allowed =
      session_path_allowed?(path, root) or
        (source == "automation" and
           session_path_allowed?(path, Path.join(config_root!(), "sessions/automations")))

    cond do
      !allowed ->
        {:error, "Invalid session path"}

      File.exists?(path) and !File.regular?(path) ->
        {:error, "Invalid session path"}

      File.exists?(path) ->
        {:ok, path}

      true ->
        {:ok, nil}
    end
  end

  def validate_session_file(_path, _source), do: {:error, "Invalid session path"}

  defp registration_project(relative) when is_binary(relative) do
    project = Workspace.resolve(relative)
    {:ok, project, Path.relative_to(project, Workspace.root())}
  rescue
    _error in [ArgumentError, File.Error] -> {:error, "Invalid project"}
  end

  defp registration_project(_relative), do: {:error, "Invalid project"}

  defp registration_session_file(path) do
    case validate_session_file(path) do
      {:ok, file} when is_binary(file) -> {:ok, file}
      {:ok, nil} -> {:error, "Session file not found"}
      {:error, message} -> {:error, message}
    end
  end

  defp registration_name(name, project) when is_binary(name) do
    case String.trim(name) do
      "" -> Path.basename(project)
      trimmed -> trimmed
    end
  end

  defp registration_name(_name, project), do: Path.basename(project)

  defp upsert_registered(attributes) do
    attributes =
      attributes
      |> Map.put(:id, registration_id())
      |> Map.put(:source, "extension")
      |> Map.put(:status, "stopped")

    %Session{}
    |> Session.changeset(attributes)
    |> Repo.insert(
      on_conflict:
        {:replace,
         [
           :name,
           :project_path,
           :relative_project,
           :pi_session_id,
           :source,
           :status,
           :updated_at
         ]},
      conflict_target: :session_file
    )
    |> case do
      {:ok, _session} ->
        {:ok, Repo.get_by!(Session, session_file: attributes.session_file) |> to_metadata()}

      {:error, changeset} ->
        {:error, changeset}
    end
    |> tap(fn
      {:ok, _session} -> notify_sessions_changed()
      {:error, _reason} -> :ok
    end)
  end

  defp registration_id, do: Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)

  defp notify_sessions_changed,
    do: Phoenix.PubSub.broadcast(WebApp.PubSub, "remote_sessions", :changed)

  defp valid_id?(id), do: is_binary(id) and Regex.match?(~r/\A[A-Za-z0-9_-]{12}\z/, id)

  defp session_path_allowed?(path, root),
    do:
      with(
        {:ok, canonical_root} <- canonical(root),
        {:ok, canonical_path} <- canonical(path),
        do: String.starts_with?(canonical_path, canonical_root <> "/"),
        else: (_ -> false)
      )

  defp canonical(path) do
    target = if File.exists?(path), do: path, else: Path.dirname(path)

    case System.cmd("readlink", ["-f", "--", target], stderr_to_stdout: true) do
      {canonical, 0} ->
        canonical = String.trim(canonical)

        {:ok,
         if(File.exists?(path), do: canonical, else: Path.join(canonical, Path.basename(path)))}

      {_error, _status} ->
        :error
    end
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
