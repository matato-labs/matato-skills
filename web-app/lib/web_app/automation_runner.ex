defmodule WebApp.AutomationRunner do
  require Logger

  alias WebApp.Automation

  def run(%Automation{} = automation) do
    with {:ok, skill_path} <- skill_path(automation.job_name),
         {:ok, output} <- script(skill_path, "preScript.ts") do
      run_automation(automation, skill_path, output)
    else
      {:error, reason} ->
        Logger.error("Automation failed", job_name: automation.job_name, reason: reason)
    end
  end

  defp run_automation(automation, _skill_path, "") do
    Logger.info("Automation skipped", job_name: automation.job_name)
  end

  defp run_automation(automation, skill_path, output) do
    with :ok <- run_pi(automation, skill_path, output),
         {:ok, _output} <- script(skill_path, "postScript.ts") do
      Logger.info("Automation completed", job_name: automation.job_name)
    else
      {:error, reason} ->
        Logger.error("Automation failed", job_name: automation.job_name, reason: reason)
    end
  end

  defp skill_path(job_name) do
    path = Path.join([System.user_home!(), ".pi", "agent", "skills", job_name])
    if File.dir?(path), do: {:ok, path}, else: {:error, "Skill not found: #{job_name}"}
  end

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
      await_settled(port, "")
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
      automation.thinking_level,
      "--skill",
      skill_path
    ] ++ daily_session_args(automation)
  end

  defp daily_session_args(%{daily_session: false}), do: []

  defp daily_session_args(automation) do
    storage = storage_path()
    date = Date.utc_today() |> Date.to_iso8601()

    [
      "--session-id",
      "#{automation.job_name}-#{date}",
      "--session-dir",
      Path.join(storage, "sessions")
    ]
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
    prompt = ["/skill:#{automation.job_name}", "", automation.user_prompt]
    prompt = if is_nil(output), do: prompt, else: prompt ++ ["", "Pre-script output:", output]
    message = %{id: automation.job_name, type: "prompt", message: Enum.join(prompt, "\n")}

    if Port.command(port, Jason.encode!(message) <> "\n"),
      do: :ok,
      else: {:error, "Could not send Pi prompt"}
  end

  defp await_settled(port, buffer) do
    receive do
      {^port, {:data, chunk}} -> process_output(port, buffer <> chunk)
      {^port, {:exit_status, 0}} -> {:error, "Pi exited before settling"}
      {^port, {:exit_status, status}} -> {:error, "Pi exited with status #{status}"}
    end
  end

  defp process_output(port, output) do
    case String.split(output, "\n") do
      [partial] ->
        await_settled(port, partial)

      lines ->
        {complete, [partial]} = Enum.split(lines, -1)

        case Enum.find_value(complete, &rpc_state/1) do
          :settled ->
            Port.close(port)
            :ok

          {:error, reason} ->
            Port.close(port)
            {:error, reason}

          nil ->
            await_settled(port, partial)
        end
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
