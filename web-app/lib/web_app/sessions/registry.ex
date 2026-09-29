defmodule WebApp.Sessions.Registry do
  use GenServer

  alias WebApp.Sessions.{Agent, Store, Workspace}

  @creation_limit 10
  @creation_window_ms 60_000

  def start_link(_options), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  def list, do: Store.list()
  def subscribe, do: Phoenix.PubSub.subscribe(WebApp.PubSub, "remote_sessions")

  def create(relative, options \\ %{}) do
    case GenServer.call(__MODULE__, {:create, relative, options}) do
      {:ok, id} -> await_created(id)
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def open(id, identity \\ nil),
    do:
      with(
        :ok <- GenServer.call(__MODULE__, {:open, id, identity}),
        :ok <- Agent.await_ready(id),
        do: :ok
      )

  def create_general do
    case GenServer.call(__MODULE__, :create_general) do
      {:ok, id} -> await_created(id)
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def stop(id), do: GenServer.call(__MODULE__, {:stop, id}, 20_000)
  def delete(id), do: GenServer.call(__MODULE__, {:delete, id}, 20_000)
  def register_automation(name), do: GenServer.call(__MODULE__, {:register_automation, name})

  def complete_automation(id, status),
    do: GenServer.cast(__MODULE__, {:complete_automation, id, status})

  @impl true
  def init(:ok) do
    Store.mark_interrupted()
    {:ok, %{creation_times: []}}
  end

  @impl true
  def handle_call({:create, relative, options}, _from, state),
    do: rate_limited_create(state, fn state -> create_session(relative, options, state) end)

  def handle_call(:create_general, _from, state),
    do: rate_limited_create(state, &create_general_session/1)

  def handle_call({:register_automation, name}, _from, state) do
    id = Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)
    project = Store.config_root!()
    session_file = automation_session_file(id)
    File.mkdir_p!(Path.dirname(session_file))
    write_automation_session!(session_file, id, project)

    case Store.create(%{
           id: id,
           name: name,
           project_path: project,
           relative_project: ".",
           session_file: session_file,
           pi_session_id: id,
           status: "working",
           source: "automation"
         }) do
      {:ok, _session} ->
        notify_sessions_changed()
        {:reply, {:ok, %{id: id, session_file: session_file}}, state}

      {:error, reason} ->
        File.rm(session_file)
        {:reply, {:error, format_error(reason)}, state}
    end
  end

  def handle_call({:open, id, identity}, _from, state) do
    with metadata when not is_nil(metadata) <- Store.get(id),
         {:ok, metadata} <- Store.validate_metadata(metadata),
         :ok <- ensure_unique_writer(metadata),
         :ok <- start_or_reuse(metadata, identity) do
      {:reply, :ok, state}
    else
      nil -> {:reply, {:error, "Session not found"}, state}
      {:error, reason} -> {:reply, {:error, format_error(reason)}, state}
    end
  end

  def handle_call({:stop, id}, _from, state) do
    if Agent.whereis(id) do
      snapshot = Agent.snapshot(id)

      if snapshot.status in [:working, :waiting_for_input, :retrying, :compacting],
        do: Agent.command(id, %{"type" => "abort"})

      Agent.stop(id)
    end

    put_status(id, :stopped)
    {:reply, :ok, state}
  catch
    :exit, _reason ->
      put_status(id, :interrupted)
      {:reply, :ok, state}
  end

  def handle_call({:delete, id}, _from, state) do
    with metadata when not is_nil(metadata) <- Store.get(id),
         {:ok, _session_file} <-
           Store.validate_session_file(metadata["session_file"], metadata["source"]),
         :ok <- Store.delete(id) do
      if Agent.whereis(id), do: Agent.stop(id)
      notify_sessions_changed()
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
  def handle_cast({:complete_automation, id, status}, state) do
    put_status(id, status)
    {:noreply, state}
  end

  def handle_cast({:discard_failed, id}, state) when is_binary(id) do
    if Agent.whereis(id), do: Agent.stop(id)
    Store.delete(id)
    notify_sessions_changed()
    {:noreply, state}
  end

  def handle_cast({:discard_failed, _error}, state), do: {:noreply, state}

  def handle_cast({:identity, id, file, pi_id}, state) do
    Store.update(id, %{session_file: file, pi_session_id: pi_id})
    {:noreply, state}
  end

  def handle_cast({:prompt, id, message}, state) do
    derive_session_name(id, message)
    {:noreply, state}
  end

  def handle_cast({:status, id, status}, state) do
    put_status(id, status)
    {:noreply, state}
  end

  defp rate_limited_create(state, create) do
    now = System.monotonic_time(:millisecond)
    recent = Enum.filter(state.creation_times, &(now - &1 < @creation_window_ms))
    state = %{state | creation_times: [now | recent]}

    if length(recent) >= @creation_limit,
      do: {:reply, {:error, "Session creation rate limit exceeded"}, state},
      else: create.(state)
  end

  defp create_general_session(state) do
    project = Store.config_root!()
    create_at(project, %{name: "New session", source: "general", relative_project: "."}, state)
  rescue
    error in [ArgumentError, File.Error] -> {:reply, {:error, Exception.message(error)}, state}
  end

  defp create_session(relative, options, state) do
    project = Workspace.resolve(relative)

    create_at(
      project,
      Map.put(options, :relative_project, Path.relative_to(project, Workspace.root())),
      state
    )
  rescue
    error in [ArgumentError, File.Error] -> {:reply, {:error, Exception.message(error)}, state}
  end

  defp create_at(project, options, state) do
    id = Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)

    metadata = %{
      "id" => id,
      "name" => Map.get(options, :name) || Path.basename(project),
      "project" => project,
      "relative_project" => options.relative_project,
      "session_file" => nil,
      "pi_session_id" => nil,
      "source" => Map.get(options, :source, "web"),
      "identity" => Map.get(options, :identity),
      "status" => "starting"
    }

    case start(metadata) do
      {:ok, _pid} ->
        case Store.create(%{
               id: id,
               name: metadata["name"],
               project_path: project,
               relative_project: metadata["relative_project"],
               status: "starting",
               source: metadata["source"]
             }) do
          {:ok, _session} ->
            notify_sessions_changed()
            {:reply, {:ok, id}, state}

          {:error, reason} ->
            Agent.stop(id)
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, format_error(reason)}, state}
    end
  end

  defp start(metadata, identity \\ nil),
    do:
      DynamicSupervisor.start_child(
        WebApp.Sessions.AgentSupervisor,
        {Agent,
         [
           id: metadata["id"],
           name: metadata["name"],
           project: metadata["project"],
           session_file: metadata["session_file"],
           identity: identity || metadata["identity"],
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

  defp start_or_reuse(metadata, identity) do
    case start(metadata, identity) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_unique_writer(%{"session_file" => nil}), do: :ok

  defp ensure_unique_writer(metadata) do
    duplicate =
      Enum.find(Store.list(), fn candidate ->
        candidate["id"] != metadata["id"] and
          candidate["session_file"] == metadata["session_file"] and
          Agent.whereis(candidate["id"])
      end)

    if duplicate, do: {:error, "Session file is already open"}, else: :ok
  end

  defp await_created(id) do
    case Agent.await_ready(id) do
      :ok ->
        {:ok, id}

      {:error, reason} ->
        GenServer.cast(__MODULE__, {:discard_failed, id})
        {:error, format_error(reason)}
    end
  end

  defp derive_session_name(id, message) when is_binary(message) do
    case Store.get(id) do
      %{"source" => "web", "name" => name, "project" => project} ->
        if name == Path.basename(project), do: rename_session(id, message)

      %{"source" => "general", "name" => "New session"} ->
        rename_session(id, message)

      _session ->
        :ok
    end
  end

  defp derive_session_name(_id, _message), do: :ok

  defp rename_session(id, message) do
    name =
      message
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()
      |> String.split(" ")
      |> Enum.take(6)
      |> Enum.join(" ")

    if name == "", do: :ok, else: store_session_name(id, name)
  end

  defp store_session_name(id, name) do
    {:ok, _session} = Store.update(id, %{name: name})
    notify_sessions_changed()
  end

  defp put_status(id, status) do
    Store.update(id, %{status: to_string(status)})
    notify_sessions_changed()
  end

  defp automation_session_file(id) do
    storage = Application.fetch_env!(:web_app, :automation_storage_path)
    Path.join([storage, "sessions", "automations", "#{id}.jsonl"])
  end

  defp write_automation_session!(path, id, project) do
    header = %{
      type: "session",
      version: 3,
      id: id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      cwd: project
    }

    File.write!(path, Jason.encode!(header) <> "\n", [:exclusive])
  end

  defp notify_sessions_changed,
    do: Phoenix.PubSub.broadcast(WebApp.PubSub, "remote_sessions", :changed)

  defp notify(event), do: GenServer.cast(__MODULE__, event)
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
