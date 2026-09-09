defmodule WebApp.AutomationWatcher do
  use GenServer

  require Logger

  alias WebApp.{Automation, AutomationScheduler}

  @reload_delay 250

  def start_link(_options), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    path = Application.fetch_env!(:web_app, :automations_config_path) |> Path.expand()
    File.mkdir_p!(Path.dirname(path))
    {:ok, watcher} = FileSystem.start_link(dirs: [Path.dirname(path)])
    FileSystem.subscribe(watcher)
    reload_ref = make_ref()
    send(self(), {:reload, reload_ref})
    {:ok, %{path: path, watcher: watcher, checksum: nil, timer: nil, reload_ref: reload_ref}}
  end

  @impl true
  def handle_info({:file_event, watcher, {path, _events}}, %{watcher: watcher} = state) do
    if Path.expand(path) == state.path, do: {:noreply, debounce(state)}, else: {:noreply, state}
  end

  def handle_info({:file_event, watcher, :stop}, %{watcher: watcher} = state) do
    Logger.warning("Automation file watcher stopped")
    {:stop, :normal, state}
  end

  def handle_info({:reload, reload_ref}, %{reload_ref: reload_ref} = state) do
    {:noreply, reload(%{state | timer: nil})}
  end

  def handle_info({:reload, _reload_ref}, state), do: {:noreply, state}

  defp debounce(%{timer: timer} = state) do
    if timer, do: Process.cancel_timer(timer)

    reload_ref = make_ref()
    timer = Process.send_after(self(), {:reload, reload_ref}, @reload_delay)
    %{state | timer: timer, reload_ref: reload_ref}
  end

  defp reload(state) do
    case File.read(state.path) do
      {:error, :enoent} ->
        apply_empty_config(state)

      {:ok, contents} ->
        checksum = :crypto.hash(:sha256, contents)

        if checksum == state.checksum do
          state
        else
          apply_config(state, checksum)
        end

      {:error, reason} ->
        Logger.error("Could not read automations configuration",
          path: state.path,
          reason: inspect(reason)
        )

        state
    end
  end

  defp apply_config(state, checksum) do
    with {:ok, automations} <- Automation.load(state.path),
         :ok <- AutomationScheduler.replace(automations) do
      Logger.info("Automations reloaded", count: length(automations))
      %{state | checksum: checksum}
    else
      {:error, reason} ->
        Logger.error("Could not reload automations", path: state.path, reason: reason)
        state
    end
  end

  defp apply_empty_config(state) do
    checksum = :crypto.hash(:sha256, "")

    if checksum == state.checksum do
      state
    else
      case AutomationScheduler.replace([]) do
        :ok ->
          %{state | checksum: checksum}

        {:error, reason} ->
          Logger.error("Could not clear automations", reason: reason)
          state
      end
    end
  end
end
