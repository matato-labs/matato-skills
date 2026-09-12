defmodule WebApp.AutomationScheduler do
  use Quantum, otp_app: :web_app

  alias Crontab.CronExpression.Parser
  alias Quantum.Job
  alias WebApp.Automation

  def replace(automations) when is_list(automations) do
    with {:ok, jobs} <- build_jobs(automations) do
      delete_all_jobs()
      Enum.each(jobs, &add_job/1)
      :ok
    end
  end

  defp build_jobs(automations) do
    automations
    |> Enum.reduce_while({:ok, []}, fn automation, {:ok, jobs} ->
      case build_job(automation) do
        {:ok, job} when automation.enabled -> {:cont, {:ok, [job | jobs]}}
        {:ok, _job} -> {:cont, {:ok, jobs}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> then(fn
      {:ok, jobs} -> {:ok, Enum.reverse(jobs)}
      error -> error
    end)
  end

  defp build_job(%Automation{} = automation) do
    case Parser.parse(automation.schedule, extended?(automation.schedule)) do
      {:ok, schedule} ->
        {:ok,
         new_job()
         |> Job.set_schedule(schedule)
         |> Job.set_task({WebApp.AutomationRunner, :run, [automation]})
         |> Job.set_overlap(automation.can_overlap)}

      {:error, reason} ->
        {:error, "Invalid schedule for #{automation.job_name}: #{inspect(reason)}"}
    end
  end

  defp extended?(schedule), do: schedule |> String.split() |> length() == 6
end
