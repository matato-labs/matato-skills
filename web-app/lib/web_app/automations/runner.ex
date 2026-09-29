defmodule WebApp.Automations.Runner do
  require Logger

  alias WebApp.{Automations, Execution, Sessions}

  def run(%Automations{} = automation) do
    Logger.debug("Automation started: #{automation.job_name}")
    skill_name = if automation.use_skill, do: automation.job_name, else: nil

    case Execution.prepare(skill_name) do
      :skip ->
        Logger.debug("Automation skipped: #{automation.job_name} (pre-script returned no work)")

      {:ok, prepared} ->
        run_automation(automation, skill_name, prepared)

      {:error, reason} ->
        failure(automation, reason)
    end
  end

  defp run_automation(automation, skill_name, prepared) do
    Logger.info("Automation agent started: #{automation.job_name}")
    monitor = register_automation(automation)

    options = %{
      name: automation.job_name,
      prompt: automation.user_prompt,
      skill_name: skill_name,
      model: automation.model,
      thinking_level: automation.thinking_level,
      session_args: session_args(automation, monitor)
    }

    result = Execution.run(options, prepared)
    finish_automation_monitor(monitor, result)

    case result do
      {:ok, _response} -> Logger.info("Automation completed: #{automation.job_name}")
      {:error, reason} -> failure(automation, reason)
    end
  end

  defp failure(automation, reason),
    do: Logger.error("Automation failed: #{automation.job_name}. Reason: #{reason}")

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

  defp finish_automation_monitor(%{id: id}, {:ok, _}),
    do: Sessions.complete_automation(id, :settled)

  defp finish_automation_monitor(%{id: id}, {:error, _}),
    do: Sessions.complete_automation(id, :failed)

  defp session_args(_automation, %{session_file: file}), do: ["--session", file]
  defp session_args(%{daily_session: false}, nil), do: []

  defp session_args(automation, nil) do
    date = Date.utc_today() |> Date.to_iso8601()
    ["--session-id", "#{automation.job_name}-#{date}"]
  end
end
