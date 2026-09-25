defmodule WebApp.Automations.Runner do
  require Logger

  alias WebApp.{Automations, Bots, Sessions}

  def run(%Automations{use_skill: false} = automation) do
    Logger.debug("Automation started: #{automation.job_name}")
    run_automation(automation, nil, nil)
  end

  def run(%Automations{} = automation) do
    Logger.debug("Automation started: #{automation.job_name}")

    with {:ok, skill_path} <- skill_path(automation.job_name),
         {:ok, output} <- script(skill_path, "preScript.ts") do
      run_automation(automation, skill_path, output)
    else
      {:error, reason} ->
        persist_result(automation, "Automation failed: #{reason}")
        log_failure(automation, reason)
    end
  end

  defp run_automation(%{use_skill: true} = automation, _skill_path, "") do
    Logger.debug("Automation skipped: #{automation.job_name} (pre-script returned no work)")
  end

  defp run_automation(automation, skill_path, output) do
    Logger.info("Automation agent started: #{automation.job_name}")
    monitor = register_automation(automation)

    result =
      with {:ok, response} <- run_pi(automation, skill_path, output, monitor),
           {:ok, _output} <- post_script(automation, skill_path) do
        {:ok, response}
      end

    finish_automation_monitor(monitor, result)

    case result do
      {:ok, response} ->
        persist_result(automation, response)
        Logger.info("Automation completed: #{automation.job_name}")

      {:error, reason} ->
        persist_result(automation, "Automation failed: #{reason}")
        log_failure(automation, reason)
    end
  end

  defp register_automation(%{monitor: false}), do: nil

  defp register_automation(automation) do
    case Sessions.register_automation(automation.job_name) do
      {:ok, id} ->
        id

      {:error, reason} ->
        Logger.warning("Could not monitor #{automation.job_name}: #{reason}")
        nil
    end
  end

  defp finish_automation_monitor(nil, _result), do: :ok

  defp finish_automation_monitor(%{id: id}, {:ok, response}),
    do: Sessions.complete_automation(id, :settled, response)

  defp finish_automation_monitor(%{id: id}, {:error, reason}),
    do: Sessions.complete_automation(id, :failed, reason)

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
      case System.cmd("env", ["-u", "MIX_ENV", "bun", path],
             cd: skill_path,
             env: automation_env(),
             stderr_to_stdout: true
           ) do
        {output, 0} -> {:ok, String.trim(output)}
        {output, _status} -> {:error, String.trim(output)}
      end
    else
      {:ok, nil}
    end
  end

  defp run_pi(%{bot_id: nil} = automation, skill_path, output, monitor) do
    with {:ok, executable} <- executable("pi"),
         {:ok, port} <-
           open_port(executable, pi_args(automation, skill_path, monitor), File.cwd!()),
         :ok <- send_prompt(port, automation, output, true) do
      await_settled(port, "", automation, "")
    end
  end

  defp run_pi(automation, _skill_path, output, _monitor) do
    with false <- automation.daily_session,
         %{background_remote_session_id: session_id} <- Bots.get(automation.bot_id),
         :ok <- Sessions.open(session_id),
         :owner <- await_background(session_id) do
      try do
        with :ok <- configure_model(session_id, automation.model),
             :ok <- configure_thinking(session_id, automation.thinking_level) do
          Sessions.owner_command_and_await_settled(
            session_id,
            self(),
            prompt_command(automation, output, false)
            |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
          )
        end
      after
        Sessions.release(session_id, self())
      end
    else
      nil -> {:error, "Automation bot no longer exists"}
      true -> {:error, "Bot-owned automations cannot use daily_session"}
      {:error, reason} -> {:error, reason}
    end
  catch
    :exit, _reason -> {:error, "Bot background session stopped during automation"}
  end

  defp await_background(session_id) do
    if Sessions.snapshot(session_id).status == :settled and
         Sessions.claim(session_id, self()) == :owner do
      if Sessions.snapshot(session_id).status == :settled do
        :owner
      else
        Sessions.release(session_id, self())
        retry_background(session_id)
      end
    else
      retry_background(session_id)
    end
  end

  defp retry_background(session_id) do
    Process.sleep(50)
    await_background(session_id)
  end

  defp configure_model(_session_id, nil), do: :ok

  defp configure_model(session_id, model) do
    case String.split(model, "/", parts: 2) do
      [provider, model_id] when provider != "" and model_id != "" ->
        command_ok(
          Sessions.owner_command(session_id, self(), %{
            "type" => "set_model",
            "provider" => provider,
            "modelId" => model_id
          })
        )

      _ ->
        {:error, "Bot automation model must be provider/model"}
    end
  end

  defp configure_thinking(_session_id, nil), do: :ok

  defp configure_thinking(session_id, level),
    do:
      command_ok(
        Sessions.owner_command(session_id, self(), %{
          "type" => "set_thinking_level",
          "level" => level
        })
      )

  defp command_ok(:ok), do: :ok
  defp command_ok({:ok, _data}), do: :ok
  defp command_ok(error), do: error

  defp executable(name) do
    case System.find_executable(name) do
      nil -> {:error, "#{name} executable not found"}
      path -> {:ok, path}
    end
  end

  defp pi_args(automation, skill_path, monitor) do
    [
      "--mode",
      "rpc",
      "--name",
      automation_name(automation),
      "--approve",
      "--model",
      automation.model,
      "--thinking",
      automation.thinking_level
    ] ++ skill_args(skill_path) ++ session_args(automation, monitor)
  end

  defp skill_args(nil), do: []
  defp skill_args(skill_path), do: ["--skill", skill_path]

  defp session_args(_automation, %{session_file: session_file}),
    do: ["--session", session_file]

  defp session_args(%{daily_session: false}, nil), do: []

  defp session_args(automation, nil) do
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
       {:env,
        [
          {~c"MIX_ENV", false}
          | Enum.map(automation_env(), fn {key, value} ->
              {String.to_charlist(key), String.to_charlist(value)}
            end)
        ]},
       {:args, Enum.map(args, &String.to_charlist/1)}
     ])}
  rescue
    error -> {:error, Exception.message(error)}
  end

  @automation_environment_names ["DISCORD_BOT_TOKEN", "DISCORD_GUILD_ID", "DISCORD_CHANNEL_IDS"]

  defp automation_env do
    [
      {"MATATO_PI_CONFIG", storage_path()}
      | Enum.flat_map(@automation_environment_names, &environment_value/1)
    ]
  end

  defp environment_value(name) do
    case System.fetch_env(name) do
      {:ok, value} -> [{name, value}]
      :error -> []
    end
  end

  defp storage_path, do: Application.fetch_env!(:web_app, :automation_storage_path)

  defp send_prompt(port, automation, output, include_identity) do
    message = prompt_command(automation, output, include_identity)

    if Port.command(port, Jason.encode!(message) <> "\n"),
      do: :ok,
      else: {:error, "Could not send Pi prompt"}
  end

  defp prompt_command(automation, output, include_identity) do
    identity = if include_identity, do: bot_identity(automation), else: []
    prompt = skill_prompt(automation) ++ identity ++ [automation.user_prompt]
    prompt = if is_nil(output), do: prompt, else: prompt ++ ["", "Automation context:", output]
    %{id: automation.job_name, type: "prompt", message: Enum.join(prompt, "\n")}
  end

  defp skill_prompt(%{use_skill: false}), do: []
  defp skill_prompt(automation), do: ["/skill:#{automation.job_name}", ""]

  defp bot_identity(automation) do
    case Bots.identity(automation.bot_id) do
      nil -> []
      identity -> [identity, ""]
    end
  end

  defp await_settled(port, buffer, automation, response) do
    receive do
      {^port, {:data, chunk}} -> process_output(port, buffer <> chunk, automation, response)
      {^port, {:exit_status, 0}} -> {:error, "Pi exited before settling"}
      {^port, {:exit_status, status}} -> {:error, "Pi exited with status #{status}"}
    end
  end

  defp process_output(port, output, automation, response) do
    case String.split(output, "\n") do
      [partial] ->
        await_settled(port, partial, automation, response)

      lines ->
        {complete, [partial]} = Enum.split(lines, -1)
        Enum.each(complete, &log_progress(automation, &1))
        response = Enum.reduce(complete, response, &append_response/2)

        case Enum.find_value(complete, &rpc_state/1) do
          :settled ->
            close_port(port)
            {:ok, response}

          {:error, reason} ->
            close_port(port)
            {:error, reason}

          nil ->
            await_settled(port, partial, automation, response)
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

  defp append_response(line, response) do
    case Jason.decode(line) do
      {:ok,
       %{"type" => "message_end", "message" => %{"role" => "assistant", "content" => content}}}
      when is_list(content) ->
        text =
          content |> Enum.filter(&(&1["type"] == "text")) |> Enum.map_join("\n", & &1["text"])

        if text == "", do: response, else: text

      _ ->
        response
    end
  end

  defp automation_name(%{bot_id: nil} = automation), do: automation.job_name

  defp automation_name(automation), do: Bots.name(automation.bot_id) || automation.job_name

  defp persist_result(%{bot_id: nil}, _content), do: :ok
  defp persist_result(_automation, _content), do: :ok

  defp rpc_state(line) do
    case Jason.decode(line) do
      {:ok, %{"type" => "agent_settled"}} -> :settled
      {:ok, %{"type" => "response", "success" => false, "error" => error}} -> {:error, error}
      _ -> nil
    end
  end
end
