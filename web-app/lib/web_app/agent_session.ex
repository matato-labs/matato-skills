defmodule WebApp.AgentSession do
  use GenServer

  require Logger

  alias WebApp.{AgentFanout, AgentState, Rpc.Framer}

  @command_timeout 15_000
  @max_record 16_777_216
  @max_stderr 8_192

  def child_spec(options) do
    %{id: options[:id], start: {__MODULE__, :start_link, [options]}, restart: :temporary}
  end

  def start_link(options), do: GenServer.start_link(__MODULE__, options, name: via(options[:id]))
  def snapshot(id), do: GenServer.call(via(id), :snapshot)

  def await_ready(id) do
    GenServer.call(via(id), :await_ready, @command_timeout + 1_000)
  catch
    :exit, _reason -> {:error, "Pi exited before startup completed"}
  end

  def command(id, command),
    do: GenServer.call(via(id), {:command, command}, @command_timeout + 1_000)

  def owner_command(id, owner, command),
    do: GenServer.call(via(id), {:owner_command, owner, command}, @command_timeout + 1_000)

  def claim(id, owner, takeover \\ false), do: GenServer.call(via(id), {:claim, owner, takeover})
  def release(id, owner), do: GenServer.cast(via(id), {:release, owner})
  def respond(id, response), do: GenServer.call(via(id), {:respond, response})
  def respond(id, owner, response), do: GenServer.call(via(id), {:respond, owner, response})
  def stop(id), do: GenServer.stop(via(id), :normal)
  def whereis(id), do: GenServer.whereis(via(id))

  defp via(id), do: {:via, Registry, {WebApp.ProcessRegistry, id}}

  @impl true
  def init(options) do
    executable =
      System.find_executable(options[:executable] || "pi") || raise "Pi executable not found"

    stderr_dir = Application.fetch_env!(:web_app, :database_path) |> Path.dirname()
    File.mkdir_p!(stderr_dir)
    File.chmod!(stderr_dir, 0o700)

    args = pi_args(options)

    stderr_path =
      Path.join(stderr_dir, ".stderr-#{options[:id]}-#{System.unique_integer([:positive])}")

    port = open_port(executable, args, options[:project], stderr_path)

    state = %{
      id: options[:id],
      project: options[:project],
      port: port,
      stderr_path: stderr_path,
      buffer: "",
      pending: %{},
      startup_waiters: [],
      sequence: 0,
      owner: nil,
      owner_monitor: nil,
      dialog_timer: nil,
      prompt_times: [],
      closing: false,
      notifier: options[:notifier] || fn _event -> :ok end,
      view: AgentState.new(interrupted: options[:interrupted] || false)
    }

    {:ok, state, {:continue, :discover}}
  end

  @impl true
  def handle_continue(:discover, state),
    do: {:noreply, send_command(state, %{"type" => "get_state"}, :state, nil)}

  @impl true
  def handle_call(:snapshot, _from, state), do: {:reply, state.view, state}

  def handle_call(:await_ready, from, %{view: %{status: :starting}} = state),
    do: {:noreply, %{state | startup_waiters: [from | state.startup_waiters]}}

  def handle_call(:await_ready, _from, %{view: %{status: status}} = state)
      when status in [:failed, :interrupted],
      do: {:reply, {:error, state.view.error || "Pi failed to start"}, state}

  def handle_call(:await_ready, _from, state), do: {:reply, :ok, state}

  def handle_call({:owner_command, owner, command}, from, state) do
    if state.owner == owner,
      do: handle_call({:command, command}, from, state),
      else: {:reply, {:error, "Only the interaction owner can control this session"}, state}
  end

  def handle_call({:command, _command}, _from, %{view: %{status: :starting}} = state),
    do: {:reply, {:error, "Pi is still starting"}, state}

  def handle_call({:command, %{"message" => message}}, _from, state)
      when byte_size(message) > 100_000,
      do: {:reply, {:error, "Prompt exceeds 100 KB"}, state}

  def handle_call({:command, %{"type" => type} = command}, from, state)
      when type in ["prompt", "steer", "follow_up"] do
    now = System.monotonic_time(:millisecond)
    recent = Enum.filter(state.prompt_times, &(now - &1 < 1_000))

    if length(recent) >= 10,
      do: {:reply, {:error, "Prompt rate limit exceeded"}, %{state | prompt_times: recent}},
      else:
        {:noreply, send_command(%{state | prompt_times: [now | recent]}, command, :command, from)}
  end

  def handle_call({:command, command}, from, state),
    do: {:noreply, send_command(state, command, :command, from)}

  def handle_call({:claim, owner, takeover}, _from, state) do
    cond do
      state.owner == owner -> {:reply, :owner, state}
      is_nil(state.owner) -> {:reply, :owner, set_owner(state, owner)}
      takeover -> {:reply, :owner, set_owner(state, owner)}
      true -> {:reply, :observer, state}
    end
  end

  def handle_call({:respond, response}, _from, state), do: deliver_response(response, state)

  def handle_call({:respond, owner, response}, _from, %{owner: owner} = state),
    do: deliver_response(response, state)

  def handle_call({:respond, _owner, _response}, _from, state),
    do: {:reply, {:error, "Only the interaction owner can answer"}, state}

  defp deliver_response(response, state) do
    if is_nil(state.view.dialog) or state.view.dialog["id"] != response["id"] do
      {:reply, {:error, "This interaction is no longer pending"}, state}
    else
      true = Port.command(state.port, Jason.encode!(response) <> "\n")
      state = cancel_dialog_timer(state)
      {:reply, :ok, publish(%{state | view: AgentState.clear_dialog(state.view)})}
    end
  end

  @impl true
  def handle_cast({:release, owner}, %{owner: owner} = state),
    do: {:noreply, clear_owner(state)}

  def handle_cast({:release, _owner}, state), do: {:noreply, state}

  @impl true
  def handle_info({port, {:data, chunk}}, %{port: port, closing: false} = state) do
    {lines, buffer} = Framer.push(state.buffer, chunk)

    if byte_size(buffer) > @max_record or Enum.any?(lines, &(byte_size(&1) > @max_record)) do
      Port.close(port)
      {:noreply, protocol_failure(state, "Pi emitted an overlong protocol record")}
    else
      {:noreply, Enum.reduce(lines, %{state | buffer: buffer}, &decode/2)}
    end
  end

  def handle_info({_port, {:data, _chunk}}, state), do: {:noreply, state}

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    diagnostics = stderr_diagnostics(state.stderr_path)

    error =
      Enum.join(Enum.reject(["Pi exited with status #{status}", diagnostics], &(&1 == "")), ": ")

    if !state.closing,
      do: Logger.warning("Pi RPC child exited", session_id: state.id, status: status)

    fail_pending(state.pending, error)
    reply_waiters(state.startup_waiters, {:error, error})
    view = if state.closing, do: state.view, else: AgentState.exit(state.view, error)
    publish(%{state | view: view, pending: %{}})
    {:stop, :normal, %{state | pending: %{}}}
  end

  def handle_info({:command_timeout, id}, state) do
    case Map.pop(state.pending, id) do
      {nil, _pending} ->
        {:noreply, state}

      {%{kind: kind}, rest} = result when kind in [:state, :messages] ->
        {pending, _rest} = result
        error = "Pi startup command timed out"
        reply(pending.from, {:error, error})
        Port.close(state.port)
        {:noreply, protocol_failure(%{state | pending: rest}, error)}

      {%{kind: :commands}, rest} ->
        error = "Command discovery failed: Pi did not respond"
        view = AgentState.commands_failed(state.view, error)
        {:noreply, publish(%{state | pending: rest, view: view})}

      {pending, rest} ->
        error = "Pi command timed out; delivery is uncertain and was not retried"
        reply(pending.from, {:error, error})
        view = AgentState.command_error(state.view, error)
        {:noreply, publish(%{state | pending: rest, view: view})}
    end
  end

  def handle_info({:dialog_timeout, id}, %{view: %{dialog: %{"id" => id}}} = state),
    do:
      {:noreply, publish(%{state | dialog_timer: nil, view: AgentState.clear_dialog(state.view)})}

  def handle_info({:dialog_timeout, _id}, state), do: {:noreply, state}
  def handle_info(:stop_protocol_failure, state), do: {:stop, :normal, state}

  def handle_info(
        {:DOWN, monitor, :process, owner, _reason},
        %{owner: owner, owner_monitor: monitor} = state
      ),
      do: {:noreply, clear_owner(state)}

  @impl true
  def terminate(_reason, state) do
    if Port.info(state.port), do: Port.close(state.port)
    File.rm(state.stderr_path)
    :ok
  end

  defp pi_args(options) do
    package_root = Application.fetch_env!(:web_app, :pi_package_root)
    project_skills = Path.join(options[:project], ".pi/skills")
    project_prompts = Path.join(options[:project], ".pi/prompts")

    [
      "--mode",
      "rpc",
      "--name",
      options[:name],
      "--approve",
      "--no-extensions",
      "--extension",
      package_root,
      "--no-skills",
      "--skill",
      Path.join(package_root, "skills"),
      "--no-prompt-templates",
      "--prompt-template",
      Path.join(package_root, "prompts")
    ]
    |> add_resource("--skill", project_skills)
    |> add_resource("--prompt-template", project_prompts)
    |> add_identity(options[:identity])
    |> then(fn args ->
      if options[:session_file], do: args ++ ["--session", options[:session_file]], else: args
    end)
  end

  defp add_resource(args, flag, path) do
    if File.dir?(path), do: args ++ [flag, path], else: args
  end

  defp add_identity(args, nil), do: args
  defp add_identity(args, identity), do: args ++ ["--append-system-prompt", identity]

  defp open_port(executable, args, project, stderr_path) do
    shell = System.find_executable("sh") || raise "sh executable not found"
    script = ~S|stderr="$1"; shift; exec "$@" 2>"$stderr"|
    shell_args = ["-c", script, "matato-pi", stderr_path, executable | args]

    Port.open({:spawn_executable, String.to_charlist(shell)}, [
      :binary,
      :exit_status,
      :use_stdio,
      {:args, Enum.map(shell_args, &String.to_charlist/1)},
      {:cd, String.to_charlist(project)}
    ])
  end

  defp send_command(state, command, kind, from) do
    id = "#{state.id}-#{state.sequence + 1}"
    payload = Map.put(command, "id", id)

    try do
      true = Port.command(state.port, Jason.encode!(payload) <> "\n")
      timer = Process.send_after(self(), {:command_timeout, id}, @command_timeout)
      pending = Map.put(state.pending, id, %{kind: kind, from: from, timer: timer})
      %{state | pending: pending, sequence: state.sequence + 1}
    rescue
      ArgumentError -> protocol_failure(state, "Pi exited before accepting a command")
    end
  end

  defp decode(_line, %{closing: true} = state), do: state
  defp decode("", state), do: state

  defp decode(line, state) do
    case Jason.decode(line) do
      {:ok, %{"type" => "response"} = response} ->
        handle_response(response, state)

      {:ok, event} when is_map(event) ->
        publish_event(event, state)

      {:ok, _value} ->
        Port.close(state.port)
        protocol_failure(state, "Pi emitted a non-object protocol record")

      {:error, _reason} ->
        Port.close(state.port)
        protocol_failure(state, "Pi emitted malformed JSON")
    end
  rescue
    _error ->
      if Port.info(state.port), do: Port.close(state.port)
      protocol_failure(state, "Pi emitted an invalid protocol object")
  end

  defp handle_response(%{"id" => id} = response, state) do
    case Map.pop(state.pending, id) do
      {nil, _rest} ->
        state

      {pending, rest} ->
        Process.cancel_timer(pending.timer)
        apply_response(response, pending, %{state | pending: rest})
    end
  end

  defp handle_response(_response, state), do: state

  defp apply_response(%{"success" => false} = response, %{kind: :commands}, state) do
    error = "Command discovery failed: #{response["error"] || "Pi rejected the request"}"
    publish(%{state | view: AgentState.commands_failed(state.view, error)})
  end

  defp apply_response(%{"success" => false} = response, pending, state) do
    error = response["error"] || "Pi rejected the command"
    reply(pending.from, {:error, error})

    if pending.kind in [:state, :messages] do
      Port.close(state.port)
      protocol_failure(state, error)
    else
      publish(%{state | view: AgentState.command_error(state.view, error)})
    end
  end

  defp apply_response(%{"data" => data}, %{kind: :state}, state) do
    view = AgentState.discover(state.view, data)
    state.notifier.({:identity, state.id, data["sessionFile"], data["sessionId"]})

    state
    |> Map.put(:view, view)
    |> send_command(%{"type" => "get_messages"}, :messages, nil)
    |> send_command(%{"type" => "get_commands"}, :commands, nil)
  end

  defp apply_response(%{"data" => data}, %{kind: :messages}, state) do
    reply_waiters(state.startup_waiters, :ok)
    publish(%{state | startup_waiters: [], view: AgentState.hydrate(state.view, data)})
  end

  defp apply_response(%{"data" => %{"commands" => commands}}, %{kind: :commands}, state) do
    publish(%{state | view: AgentState.commands_ready(state.view, commands)})
  end

  defp apply_response(response, pending, state) do
    result = if Map.has_key?(response, "data"), do: {:ok, response["data"]}, else: :ok
    reply(pending.from, result)
    state
  end

  defp publish_event(%{"type" => "extension_ui_request", "method" => method} = event, state)
       when method in ["setTitle", "set_editor_text", "setStatus", "setWidget"] do
    AgentFanout.broadcast(state.id, {:agent_hint, event})
    state
  end

  defp publish_event(%{"type" => "extension_ui_request", "method" => method} = event, state)
       when method in ["select", "confirm", "input", "editor"] do
    state = state |> cancel_dialog_timer() |> schedule_dialog_timer(event)
    publish(%{state | view: AgentState.apply(state.view, event)})
  end

  defp publish_event(event, state),
    do: publish(%{state | view: AgentState.apply(state.view, event)})

  defp publish(state) do
    state.notifier.({:status, state.id, state.view.status})
    AgentFanout.broadcast(state.id, {:agent_snapshot, state.view})
    state
  end

  defp protocol_failure(state, error) do
    Logger.warning("Pi RPC protocol failure", session_id: state.id, reason: error)
    send(self(), :stop_protocol_failure)
    fail_pending(state.pending, error)
    reply_waiters(state.startup_waiters, {:error, error})

    publish(%{
      state
      | closing: true,
        pending: %{},
        startup_waiters: [],
        view: AgentState.exit(state.view, error)
    })
  end

  defp fail_pending(pending, error),
    do: Enum.each(pending, fn {_id, request} -> reply(request.from, {:error, error}) end)

  defp reply_waiters(waiters, response), do: Enum.each(waiters, &GenServer.reply(&1, response))

  defp set_owner(state, owner) do
    state = clear_owner(state)
    %{state | owner: owner, owner_monitor: Process.monitor(owner)}
  end

  defp clear_owner(%{owner_monitor: nil} = state), do: %{state | owner: nil}

  defp clear_owner(state) do
    Process.demonitor(state.owner_monitor, [:flush])
    %{state | owner: nil, owner_monitor: nil}
  end

  defp schedule_dialog_timer(state, %{"timeout" => timeout, "id" => id})
       when is_integer(timeout) and timeout > 0,
       do: %{state | dialog_timer: Process.send_after(self(), {:dialog_timeout, id}, timeout)}

  defp schedule_dialog_timer(state, _event), do: state

  defp cancel_dialog_timer(%{dialog_timer: nil} = state), do: state

  defp cancel_dialog_timer(state) do
    Process.cancel_timer(state.dialog_timer)
    %{state | dialog_timer: nil}
  end

  defp stderr_diagnostics(path) do
    case File.read(path) do
      {:ok, output} ->
        output
        |> binary_part(
          max(byte_size(output) - @max_stderr, 0),
          min(byte_size(output), @max_stderr)
        )
        |> String.replace_invalid()
        |> String.trim()

      {:error, _reason} ->
        ""
    end
  end

  defp reply(nil, _response), do: :ok
  defp reply(from, response), do: GenServer.reply(from, response)
end
