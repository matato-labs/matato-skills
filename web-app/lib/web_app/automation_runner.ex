defmodule WebApp.AutomationRunner do
  require Logger

  alias WebApp.Automation

  def run(%Automation{use_skill: false} = automation) do
    Logger.debug("Automation started: #{automation.job_name}")
    run_automation(automation, nil, nil)
  end

  def run(%Automation{} = automation) do
    Logger.debug("Automation started: #{automation.job_name}")

    with {:ok, skill_path} <- skill_path(automation.job_name),
         {:ok, output} <- script(skill_path, "preScript.ts") do
      run_automation(automation, skill_path, output)
    else
      {:error, reason} -> log_failure(automation, reason)
    end
  end

  defp run_automation(%{use_skill: true} = automation, _skill_path, "") do
    Logger.debug("Automation skipped: #{automation.job_name} (pre-script returned no work)")
  end

  defp run_automation(automation, skill_path, output) do
    monitor_id = register_automation(automation)
    Logger.info("Automation agent started: #{automation.job_name}")

    result =
      with :ok <- run_pi(automation, skill_path, output),
           {:ok, _output} <- post_script(automation, skill_path) do
        :ok
      end

    finish_automation_monitor(monitor_id, result)

    case result do
      :ok -> Logger.info("Automation completed: #{automation.job_name}")
      {:error, reason} -> log_failure(automation, reason)
    end
  end

  defp register_automation(%{monitor: false}), do: nil

  defp register_automation(automation) do
    case WebApp.RemoteRegistry.register_automation(automation.job_name) do
      {:ok, id} ->
        id

      {:error, reason} ->
        Logger.warning("Could not monitor #{automation.job_name}: #{reason}")
        nil
    end
  end

  defp finish_automation_monitor(nil, _result), do: :ok

  defp finish_automation_monitor(id, :ok),
    do: WebApp.RemoteRegistry.complete_automation(id, :settled)

  defp finish_automation_monitor(id, {:error, _reason}),
    do: WebApp.RemoteRegistry.complete_automation(id, :failed)

  defp post_script(%{use_skill: false}, _skill_path), do: {:ok, nil}
  defp post_script(_automation, skill_path), do: script(skill_path, "postScript.ts")

  defp log_failure(automation, reason),
    do: Logger.error("Automation failed: #{automation.job_name}. Reason: #{reason}")

  defp skill_path(job_name) do
    paths = [default_skills_path() | package_paths()] |> Enum.map(&Path.join(&1, job_name))

    case Enum.find(paths, &File.dir?/1) do
      nil -> {:error, "Skill not found: #{job_name}. Searched: #{Enum.join(paths, ", ")}"}
      path -> {:ok, path}
    end
  end

  defp default_skills_path, do: Path.join([System.user_home!(), ".pi", "agent", "skills"])

  defp package_paths do
    settings_path = Path.join([System.user_home!(), ".pi", "agent", "settings.json"])

    with {:ok, body} <- File.read(settings_path),
         {:ok, %{"packages" => packages}} when is_list(packages) <- Jason.decode(body) do
      packages
      |> Enum.flat_map(&package_source/1)
      |> Enum.map(&Path.expand(&1, Path.dirname(settings_path)))
      |> Enum.map(&Path.join(&1, "skills"))
    else
      _ -> []
    end
  end

  defp package_source(source) when is_binary(source) do
    if String.starts_with?(source, ["/", "."]), do: [source], else: []
  end

  defp package_source(%{"source" => source}), do: package_source(source)
  defp package_source(_package), do: []

  defp script(skill_path, name) do
    path = Path.join([skill_path, "scripts", name])

    if File.regular?(path) do
      case System.cmd("bun", [path],
             cd: skill_path,
             env: [{"MATATO_PI_CONFIG", storage_path()}],
             stderr_to_stdout: true
           ) do
        {output, 0} -> {:ok, String.trim(output)}
        {output, _status} -> {:error, String.trim(output)}
      end
    else
      {:ok, nil}
    end
  end

  defp run_pi(automation, skill_path, output) do
    with {:ok, executable} <- executable("pi"),
         {:ok, port} <- open_port(executable, pi_args(automation, skill_path), File.cwd!()),
         :ok <- send_prompt(port, automation, output) do
      await_settled(port, "", automation)
    end
  end

  defp executable(name) do
    case System.find_executable(name) do
      nil -> {:error, "#{name} executable not found"}
      path -> {:ok, path}
    end
  end

  defp pi_args(automation, skill_path) do
    [
      "--mode",
      "rpc",
      "--name",
      automation.job_name,
      "--approve",
      "--model",
      automation.model,
      "--thinking",
      automation.thinking_level
    ] ++ skill_args(skill_path) ++ daily_session_args(automation)
  end

  defp skill_args(nil), do: []
  defp skill_args(skill_path), do: ["--skill", skill_path]

  defp daily_session_args(%{daily_session: false}), do: []

  defp daily_session_args(automation) do
    date = Date.utc_today() |> Date.to_iso8601()
    ["--session-id", "#{automation.job_name}-#{date}"]
  end

  defp open_port(executable, args, working_directory) do
    {:ok,
     Port.open({:spawn_executable, String.to_charlist(executable)}, [
       :binary,
       :exit_status,
       :use_stdio,
       {:cd, String.to_charlist(working_directory)},
       {:env, [{~c"MATATO_PI_CONFIG", String.to_charlist(storage_path())}]},
       {:args, Enum.map(args, &String.to_charlist/1)}
     ])}
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp storage_path, do: Application.fetch_env!(:web_app, :automation_storage_path)

  defp send_prompt(port, automation, output) do
    prompt = skill_prompt(automation) ++ [automation.user_prompt]
    prompt = if is_nil(output), do: prompt, else: prompt ++ ["", "Automation context:", output]
    message = %{id: automation.job_name, type: "prompt", message: Enum.join(prompt, "\n")}

    if Port.command(port, Jason.encode!(message) <> "\n"),
      do: :ok,
      else: {:error, "Could not send Pi prompt"}
  end

  defp skill_prompt(%{use_skill: false}), do: []
  defp skill_prompt(automation), do: ["/skill:#{automation.job_name}", ""]

  defp await_settled(port, buffer, automation) do
    receive do
      {^port, {:data, chunk}} -> process_output(port, buffer <> chunk, automation)
      {^port, {:exit_status, 0}} -> {:error, "Pi exited before settling"}
      {^port, {:exit_status, status}} -> {:error, "Pi exited with status #{status}"}
    end
  end

  defp process_output(port, output, automation) do
    case String.split(output, "\n") do
      [partial] ->
        await_settled(port, partial, automation)

      lines ->
        {complete, [partial]} = Enum.split(lines, -1)
        Enum.each(complete, &log_progress(automation, &1))

        case Enum.find_value(complete, &rpc_state/1) do
          :settled ->
            close_port(port)
            :ok

          {:error, reason} ->
            close_port(port)
            {:error, reason}

          nil ->
            await_settled(port, partial, automation)
        end
    end
  end

  defp close_port(port) do
    Port.close(port)
  rescue
    ArgumentError -> :ok
  end

  defp log_progress(automation, line) do
    case Jason.decode(line) do
      {:ok, %{"type" => "tool_execution_start", "toolName" => tool_name}} ->
        Logger.info("Automation agent tool started: #{automation.job_name} (#{tool_name})")

      {:ok, %{"type" => "tool_execution_end", "toolName" => tool_name, "isError" => true}} ->
        Logger.warning("Automation agent tool failed: #{automation.job_name} (#{tool_name})")

      {:ok, %{"type" => "tool_execution_end", "toolName" => tool_name}} ->
        Logger.info("Automation agent tool completed: #{automation.job_name} (#{tool_name})")

      _ ->
        :ok
    end
  end

  defp rpc_state(line) do
    case Jason.decode(line) do
      {:ok, %{"type" => "agent_settled"}} -> :settled
      {:ok, %{"type" => "response", "success" => false, "error" => error}} -> {:error, error}
      _ -> nil
    end
  end
end
