defmodule WebApp.Execution do
  @moduledoc "Skill scripts and Pi RPC execution for automations."
  use Boundary, top_level?: true, deps: [], exports: []
  require Logger

  def prepare(nil), do: {:ok, {nil, nil}}

  def prepare(skill_name) do
    with {:ok, path} <- skill_path(skill_name),
         {:ok, output} <- script(path, "preScript.ts") do
      if output == "", do: :skip, else: {:ok, {path, output}}
    end
  end

  def run(options, {skill_path, output}) do
    with {:ok, response} <- run_pi(options, skill_path, output),
         {:ok, _} <- post_script(skill_path) do
      {:ok, response}
    end
  end

  defp post_script(nil), do: {:ok, nil}
  defp post_script(path), do: script(path, "postScript.ts")

  defp skill_path(name) do
    bundled = Application.fetch_env!(:web_app, :pi_package_root) |> Path.join("skills")

    paths =
      [Path.join([System.user_home!(), ".pi", "agent", "skills"]) | package_paths()] ++ [bundled]

    paths = Enum.map(paths, &Path.join(&1, name))

    case Enum.find(paths, &File.dir?/1) do
      nil -> {:error, "Skill not found: #{name}. Searched: #{Enum.join(paths, ", ")}"}
      path -> {:ok, path}
    end
  end

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
  defp package_source(_), do: []

  defp script(skill_path, name) do
    path = Path.join([skill_path, "scripts", name])

    if File.regular?(path) do
      case System.cmd("env", ["-u", "MIX_ENV", "bun", path],
             cd: skill_path,
             env: execution_env(),
             stderr_to_stdout: true
           ) do
        {output, 0} -> {:ok, String.trim(output)}
        {output, _} -> {:error, String.trim(output)}
      end
    else
      {:ok, nil}
    end
  end

  defp run_pi(options, skill_path, output) do
    with {:ok, executable} <- executable("pi"),
         :ok <- ensure_cwd(),
         {:ok, port} <- open_port(executable, pi_args(options, skill_path), storage_path()) do
      try do
        with :ok <- send_prompt(port, options, output) do
          required =
            if Map.get(options, :require_success, false),
              do: "Pi settled without a successful assistant turn",
              else: nil

          await_settled(port, "", options.name, "", required)
        end
      after
        close_port(port)
      end
    end
  end

  defp ensure_cwd do
    with :ok <- File.mkdir_p(storage_path()),
         :ok <- File.chmod(storage_path(), 0o700) do
      :ok
    else
      {:error, reason} -> {:error, "Could not prepare Pi working directory: #{inspect(reason)}"}
    end
  end

  defp executable(name) do
    case System.find_executable(name) do
      nil -> {:error, "#{name} executable not found"}
      path -> {:ok, path}
    end
  end

  defp pi_args(options, skill_path) do
    ["--mode", "rpc", "--name", options.name, "--approve"] ++
      optional_arg("--model", Map.get(options, :model)) ++
      optional_arg("--thinking", Map.get(options, :thinking_level)) ++
      optional_arg("--skill", skill_path) ++ Map.get(options, :session_args, [])
  end

  defp optional_arg(_flag, nil), do: []
  defp optional_arg(flag, value), do: [flag, value]

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
          | Enum.map(execution_env(), fn {key, value} ->
              {String.to_charlist(key), String.to_charlist(value)}
            end)
        ]},
       {:args, Enum.map(args, &String.to_charlist/1)}
     ])}
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp execution_env, do: [{"MATATO_PI_CONFIG", storage_path()}]
  defp storage_path, do: Application.fetch_env!(:web_app, :automation_storage_path)

  defp send_prompt(port, options, output) do
    prompt = if Map.get(options, :skill_name), do: ["/skill:#{options.skill_name}", ""], else: []
    prompt = prompt ++ [options.prompt]
    prompt = if is_nil(output), do: prompt, else: prompt ++ ["", "Skill context:", output]
    message = %{id: options.name, type: "prompt", message: Enum.join(prompt, "\n")}

    if Port.command(port, Jason.encode!(message) <> "\n"),
      do: :ok,
      else: {:error, "Could not send Pi prompt"}
  rescue
    ArgumentError -> {:error, "Pi exited before accepting prompt"}
  end

  defp await_settled(port, buffer, name, response, failure) do
    receive do
      {^port, {:data, chunk}} -> process_output(port, buffer <> chunk, name, response, failure)
      {^port, {:exit_status, 0}} -> {:error, "Pi exited before settling"}
      {^port, {:exit_status, status}} -> {:error, "Pi exited with status #{status}"}
    end
  end

  defp process_output(port, output, name, response, failure) do
    case String.split(output, "\n") do
      [partial] ->
        await_settled(port, partial, name, response, failure)

      lines ->
        {complete, [partial]} = Enum.split(lines, -1)

        {response, failure, state} =
          Enum.reduce(complete, {response, failure, nil}, fn line, {text, error, state} ->
            event =
              case Jason.decode(line) do
                {:ok, value} -> value
                _ -> %{}
              end

            log_progress(name, event)
            next_state = rpc_state(event)

            {append_response(event, text), failure(event, error),
             if(match?({:error, _}, next_state), do: next_state, else: state || next_state)}
          end)

        case state do
          :settled -> if failure, do: {:error, failure}, else: {:ok, response}
          {:error, reason} -> {:error, reason}
          nil -> await_settled(port, partial, name, response, failure)
        end
    end
  end

  defp close_port(port) do
    Port.close(port)
  rescue
    ArgumentError -> :ok
  end

  defp log_progress(name, %{"type" => "tool_execution_start", "toolName" => tool}),
    do: Logger.info("Agent tool started: #{name} (#{tool})")

  defp log_progress(name, %{"type" => "tool_execution_end", "toolName" => tool, "isError" => true}),
       do: Logger.warning("Agent tool failed: #{name} (#{tool})")

  defp log_progress(name, %{"type" => "tool_execution_end", "toolName" => tool}),
    do: Logger.info("Agent tool completed: #{name} (#{tool})")

  defp log_progress(_, _), do: :ok

  defp append_response(
         %{"type" => "message_end", "message" => %{"role" => "assistant", "content" => content}},
         response
       )
       when is_list(content) do
    text = content |> Enum.filter(&(&1["type"] == "text")) |> Enum.map_join("\n", & &1["text"])
    if text == "", do: response, else: text
  end

  defp append_response(_, response), do: response

  defp failure(%{"type" => "agent_end", "messages" => messages}, previous) do
    Enum.reduce(messages, previous, fn message, error ->
      failure(%{"type" => "message_end", "message" => message}, error)
    end)
  end

  defp failure(
         %{
           "type" => "message_end",
           "message" => %{"role" => "assistant", "stopReason" => reason} = message
         },
         _previous
       )
       when reason in ["error", "aborted", "length", "deferred"] do
    "Pi assistant #{reason}: #{Map.get(message, "errorMessage", reason)}"
  end

  defp failure(
         %{
           "type" => "message_end",
           "message" => %{"role" => "assistant", "stopReason" => "stop"}
         },
         _previous
       ),
       do: nil

  defp failure(_, previous), do: previous

  defp rpc_state(%{"type" => "agent_settled"}), do: :settled

  defp rpc_state(%{"type" => "response", "success" => false, "error" => error}),
    do: {:error, error}

  defp rpc_state(%{"type" => "response", "success" => false}),
    do: {:error, "Pi RPC command failed"}

  defp rpc_state(_), do: nil
end
