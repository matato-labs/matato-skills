defmodule WebApp.RemoteRegistry do
  use GenServer

  require Logger

  alias WebApp.{AgentSession, Workspace}

  @creation_limit 10
  @creation_window_ms 60_000

  def start_link(_options), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  def list, do: GenServer.call(__MODULE__, :list)

  def create(relative) do
    case GenServer.call(__MODULE__, {:create, relative}) do
      {:ok, id} -> await_created(id)
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def open(id) do
    with :ok <- GenServer.call(__MODULE__, {:open, id}),
         :ok <- AgentSession.await_ready(id),
         do: :ok
  end

  def stop(id), do: GenServer.call(__MODULE__, {:stop, id}, 20_000)
  def delete(id), do: GenServer.call(__MODULE__, {:delete, id}, 20_000)

  @impl true
  def init(:ok) do
    path = Application.fetch_env!(:web_app, :metadata_file)
    sessions = path |> load() |> mark_interrupted()
    state = %{path: path, sessions: sessions, creation_times: []}
    persist(state)
    {:ok, state}
  end

  @impl true
  def handle_call(:list, _from, state) do
    sessions = state.sessions |> Map.values() |> Enum.sort_by(& &1["created_at"], :desc)
    {:reply, sessions, state}
  end

  def handle_call({:create, relative}, _from, state) do
    now = System.monotonic_time(:millisecond)
    recent = Enum.filter(state.creation_times, &(now - &1 < @creation_window_ms))
    state = %{state | creation_times: [now | recent]}

    if length(recent) >= @creation_limit do
      {:reply, {:error, "Session creation rate limit exceeded"}, state}
    else
      create_session(relative, state)
    end
  end

  def handle_call({:open, id}, _from, state) do
    with metadata when not is_nil(metadata) <- state.sessions[id],
         {:ok, metadata} <- validate_metadata(metadata),
         :ok <- ensure_unique_writer(metadata, state.sessions),
         :ok <- start_or_reuse(metadata) do
      {:reply, :ok, state}
    else
      nil -> {:reply, {:error, "Session not found"}, state}
      {:error, reason} -> {:reply, {:error, format_error(reason)}, state}
    end
  end

  def handle_call({:stop, id}, _from, state) do
    if AgentSession.whereis(id) do
      snapshot = AgentSession.snapshot(id)

      if snapshot.status in [:working, :waiting_for_input, :retrying, :compacting] do
        _ = AgentSession.command(id, %{"type" => "abort"})
      end

      AgentSession.stop(id)
    end

    next = put_status(state, id, :stopped)
    {:reply, :ok, next}
  catch
    :exit, _reason -> {:reply, :ok, put_status(state, id, :interrupted)}
  end

  def handle_call({:delete, id}, _from, state) do
    with metadata when not is_nil(metadata) <- state.sessions[id],
         {:ok, _session_file} <- validate_session_file(metadata["session_file"]) do
      if AgentSession.whereis(id), do: AgentSession.stop(id)
      next = %{state | sessions: Map.delete(state.sessions, id)}
      persist(next)
      {:reply, :ok, next}
    else
      nil -> {:reply, {:error, "Session not found"}, state}
      {:error, error} -> {:reply, {:error, format_error(error)}, state}
    end
  catch
    :exit, _reason -> {:reply, {:error, "Session could not be deleted"}, state}
  end

  @impl true
  def handle_cast({:discard_failed, id}, state) when is_binary(id) do
    if AgentSession.whereis(id), do: AgentSession.stop(id)
    next = %{state | sessions: Map.delete(state.sessions, id)}
    persist(next)
    {:noreply, next}
  end

  def handle_cast({:discard_failed, _error}, state), do: {:noreply, state}

  def handle_cast({:identity, id, file, pi_id}, state) do
    if state.sessions[id] do
      metadata =
        state.sessions[id] |> Map.put("session_file", file) |> Map.put("pi_session_id", pi_id)

      next = put_in(state.sessions[id], metadata)
      persist(next)
      {:noreply, next}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:status, id, status}, state), do: {:noreply, put_status(state, id, status)}

  defp validate_metadata(metadata) do
    with true <- valid_id?(metadata["id"]),
         relative when is_binary(relative) <- metadata["relative_project"],
         project <- Workspace.resolve(relative),
         {:ok, session_file} <- validate_session_file(metadata["session_file"]) do
      {:ok,
       metadata
       |> Map.put("name", Path.basename(project))
       |> Map.put("project", project)
       |> Map.put("session_file", session_file)}
    else
      _invalid -> {:error, "Invalid session metadata"}
    end
  rescue
    error in [ArgumentError, File.Error] -> {:error, Exception.message(error)}
  end

  defp start(metadata) do
    options = [
      id: metadata["id"],
      name: metadata["name"],
      project: metadata["project"],
      session_file: metadata["session_file"],
      notifier: &notify/1,
      interrupted:
        metadata["status"] in [
          "working",
          "waiting_for_input",
          "retrying",
          "compacting",
          "interrupted"
        ]
    ]

    DynamicSupervisor.start_child(WebApp.AgentSupervisor, {AgentSession, options})
  end

  defp start_or_reuse(metadata) do
    case start(metadata) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_unique_writer(%{"session_file" => nil}, _sessions), do: :ok

  defp ensure_unique_writer(metadata, sessions) do
    duplicate =
      sessions
      |> Map.values()
      |> Enum.find(fn candidate ->
        candidate["id"] != metadata["id"] and
          candidate["session_file"] == metadata["session_file"] and
          AgentSession.whereis(candidate["id"])
      end)

    if duplicate, do: {:error, "Session file is already open"}, else: :ok
  end

  defp await_created(id) do
    case AgentSession.await_ready(id) do
      :ok ->
        {:ok, id}

      {:error, reason} ->
        GenServer.cast(__MODULE__, {:discard_failed, id})
        {:error, format_error(reason)}
    end
  end

  defp create_session(relative, state) do
    project = Workspace.resolve(relative)
    id = Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)

    metadata = %{
      "id" => id,
      "name" => Path.basename(project),
      "project" => project,
      "relative_project" => Path.relative_to(project, Workspace.root()),
      "session_file" => nil,
      "pi_session_id" => nil,
      "status" => "starting",
      "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case start(metadata) do
      {:ok, _pid} ->
        next = put_in(state.sessions[id], metadata)
        persist(next)
        {:reply, {:ok, id}, next}

      {:error, reason} ->
        {:reply, {:error, format_error(reason)}, state}
    end
  rescue
    error in [ArgumentError, File.Error] -> {:reply, {:error, Exception.message(error)}, state}
  end

  defp validate_session_file(nil), do: {:ok, nil}

  defp validate_session_file(path) when is_binary(path) do
    root = Application.fetch_env!(:web_app, :session_dir) |> Path.expand()

    cond do
      !session_path_allowed?(path, root) -> {:error, "Invalid session path"}
      File.exists?(path) and !File.regular?(path) -> {:error, "Invalid session path"}
      File.exists?(path) -> {:ok, path}
      true -> {:ok, nil}
    end
  end

  defp validate_session_file(_path), do: {:error, "Invalid session path"}
  defp valid_id?(id), do: is_binary(id) and Regex.match?(~r/\A[A-Za-z0-9_-]{12}\z/, id)

  defp load(path) do
    case File.read(path) do
      {:error, :enoent} ->
        %{}

      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, sessions} when is_map(sessions) -> sessions
          _invalid -> log_invalid_metadata(path)
        end

      {:error, _reason} ->
        log_invalid_metadata(path)
    end
  end

  defp log_invalid_metadata(path) do
    Logger.warning("Ignoring invalid remote session metadata", path: path)
    %{}
  end

  defp mark_interrupted(sessions) do
    sessions
    |> Enum.filter(fn {_id, metadata} -> is_map(metadata) end)
    |> Map.new(fn {id, metadata} ->
      status = metadata["status"]

      if status in ["starting", "working", "waiting_for_input", "retrying", "compacting"],
        do: {id, Map.put(metadata, "status", "interrupted")},
        else: {id, metadata}
    end)
  end

  defp put_status(state, id, status) do
    status = to_string(status)

    if state.sessions[id] && state.sessions[id]["status"] != status do
      next = put_in(state.sessions[id]["status"], status)
      persist(next)
      next
    else
      state
    end
  end

  defp session_path_allowed?(path, root) do
    with {:ok, canonical_root} <- canonical(root),
         {:ok, canonical_path} <- canonical(path) do
      String.starts_with?(canonical_path, canonical_root <> "/")
    else
      _error -> false
    end
  end

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

  defp notify(event), do: GenServer.cast(__MODULE__, event)

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp persist(state) do
    directory = Path.dirname(state.path)
    File.mkdir_p!(directory)
    File.chmod!(directory, 0o700)
    temporary = "#{state.path}.tmp-#{System.unique_integer([:positive])}"
    File.write!(temporary, Jason.encode!(state.sessions), [:binary, :exclusive])
    File.chmod!(temporary, 0o600)
    File.rename!(temporary, state.path)
  end
end
