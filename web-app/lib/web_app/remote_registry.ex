defmodule WebApp.RemoteRegistry do
  use GenServer

  alias WebApp.{AgentSession, RemoteSessions, Workspace}

  @creation_limit 10
  @creation_window_ms 60_000

  def start_link(_options), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  def list, do: RemoteSessions.list()

  def create(relative) do
    case GenServer.call(__MODULE__, {:create, relative}) do
      {:ok, id} -> await_created(id)
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def open(id),
    do:
      with(
        :ok <- GenServer.call(__MODULE__, {:open, id}),
        :ok <- AgentSession.await_ready(id),
        do: :ok
      )

  def stop(id), do: GenServer.call(__MODULE__, {:stop, id}, 20_000)
  def delete(id), do: GenServer.call(__MODULE__, {:delete, id}, 20_000)

  @impl true
  def init(:ok) do
    WebApp.LegacyImporter.import()
    RemoteSessions.mark_interrupted()
    {:ok, %{creation_times: []}}
  end

  @impl true
  def handle_call({:create, relative}, _from, state) do
    now = System.monotonic_time(:millisecond)
    recent = Enum.filter(state.creation_times, &(now - &1 < @creation_window_ms))
    state = %{state | creation_times: [now | recent]}

    if length(recent) >= @creation_limit,
      do: {:reply, {:error, "Session creation rate limit exceeded"}, state},
      else: create_session(relative, state)
  end

  def handle_call({:open, id}, _from, state) do
    with metadata when not is_nil(metadata) <- RemoteSessions.get(id),
         {:ok, metadata} <- RemoteSessions.validate_metadata(metadata),
         :ok <- ensure_unique_writer(metadata),
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

      if snapshot.status in [:working, :waiting_for_input, :retrying, :compacting],
        do: AgentSession.command(id, %{"type" => "abort"})

      AgentSession.stop(id)
    end

    put_status(id, :stopped)
    {:reply, :ok, state}
  catch
    :exit, _reason ->
      put_status(id, :interrupted)
      {:reply, :ok, state}
  end

  def handle_call({:delete, id}, _from, state) do
    with metadata when not is_nil(metadata) <- RemoteSessions.get(id),
         {:ok, _session_file} <- RemoteSessions.validate_session_file(metadata["session_file"]),
         :ok <- RemoteSessions.delete(id) do
      if AgentSession.whereis(id), do: AgentSession.stop(id)
      {:reply, :ok, state}
    else
      nil -> {:reply, {:error, "Session not found"}, state}
      {:error, :not_found} -> {:reply, {:error, "Session not found"}, state}
      {:error, error} -> {:reply, {:error, format_error(error)}, state}
    end
  catch
    :exit, _reason -> {:reply, {:error, "Session could not be deleted"}, state}
  end

  @impl true
  def handle_cast({:discard_failed, id}, state) when is_binary(id) do
    if AgentSession.whereis(id), do: AgentSession.stop(id)
    RemoteSessions.delete(id)
    {:noreply, state}
  end

  def handle_cast({:discard_failed, _error}, state), do: {:noreply, state}

  def handle_cast({:identity, id, file, pi_id}, state) do
    RemoteSessions.update(id, %{session_file: file, pi_session_id: pi_id})
    {:noreply, state}
  end

  def handle_cast({:status, id, status}, state) do
    put_status(id, status)
    {:noreply, state}
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
      "source" => "web",
      "status" => "starting"
    }

    case start(metadata) do
      {:ok, _pid} ->
        case RemoteSessions.create(%{
               id: id,
               name: metadata["name"],
               project_path: project,
               relative_project: metadata["relative_project"],
               status: "starting",
               source: "web"
             }) do
          {:ok, _session} ->
            {:reply, {:ok, id}, state}

          {:error, reason} ->
            AgentSession.stop(id)
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, format_error(reason)}, state}
    end
  rescue
    error in [ArgumentError, File.Error] -> {:reply, {:error, Exception.message(error)}, state}
  end

  defp start(metadata),
    do:
      DynamicSupervisor.start_child(
        WebApp.AgentSupervisor,
        {AgentSession,
         [
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
         ]}
      )

  defp start_or_reuse(metadata) do
    case start(metadata) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_unique_writer(%{"session_file" => nil}), do: :ok

  defp ensure_unique_writer(metadata) do
    duplicate =
      Enum.find(RemoteSessions.list(), fn candidate ->
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

  defp put_status(id, status), do: RemoteSessions.update(id, %{status: to_string(status)})
  defp notify(event), do: GenServer.cast(__MODULE__, event)
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
