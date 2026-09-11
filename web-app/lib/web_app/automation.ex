defmodule WebApp.Automation do
  import Ecto.Query

  alias WebApp.Automations.AutomationRecord
  alias WebApp.Repo

  @enforce_keys [
    :job_name,
    :enabled,
    :schedule,
    :user_prompt,
    :daily_session,
    :model,
    :thinking_level
  ]
  defstruct [
    :job_name,
    :enabled,
    :schedule,
    :user_prompt,
    :daily_session,
    :model,
    :thinking_level,
    can_launch_sub_agents: false
  ]

  @thinking_levels ~w(off minimal low medium high xhigh max)

  def exists?, do: Repo.exists?(AutomationRecord)

  def list,
    do:
      Repo.all(from(record in AutomationRecord, order_by: [asc: record.id]))
      |> Enum.map(&to_domain/1)

  def replace(automations) when is_list(automations) do
    with :ok <- validate_schedules(automations),
         :ok <- validate_job_names(automations),
         {:ok, _} <-
           Repo.transaction(fn ->
             Repo.delete_all(AutomationRecord)
             Enum.each(automations, &insert/1)
           end) do
      notify()
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def import(path) do
    if exists?() do
      :ok
    else
      with {:ok, automations} <- load(path), :ok <- replace(automations) do
        backup(path)
      end
    end
  end

  def load(path) do
    with {:ok, body} <- File.read(path),
         {:ok, %{"automations" => automations}} <- Jason.decode(body),
         true <- is_list(automations),
         {:ok, parsed} <- parse(automations) do
      {:ok, parsed}
    else
      {:error, :enoent} -> {:ok, []}
      _ -> {:error, "Invalid automations configuration"}
    end
  end

  defp insert(automation) do
    changeset = AutomationRecord.changeset(%AutomationRecord{}, Map.from_struct(automation))

    case Repo.insert(changeset) do
      {:ok, _record} -> :ok
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp validate_schedules(automations) do
    Enum.reduce_while(automations, :ok, fn automation, :ok ->
      case Crontab.CronExpression.Parser.parse(
             automation.schedule,
             String.split(automation.schedule) |> length() == 6
           ) do
        {:ok, _schedule} ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, "Invalid schedule for #{automation.job_name}: #{inspect(reason)}"}}
      end
    end)
  end

  defp validate_job_names(automations) do
    if Enum.uniq_by(automations, & &1.job_name) == automations,
      do: :ok,
      else: {:error, "Automation job names must be unique"}
  end

  defp parse(automations) do
    automations
    |> Enum.reduce_while({:ok, []}, fn automation, {:ok, parsed} ->
      case parse_automation(automation) do
        {:ok, value} -> {:cont, {:ok, [value | parsed]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, parsed} -> {:ok, Enum.reverse(parsed)}
      :error -> {:error, "Invalid automation"}
    end
  end

  defp parse_automation(%{"dailySession" => daily_session} = automation)
       when is_boolean(daily_session) do
    with {:ok, parsed} <- parse_automation(Map.delete(automation, "dailySession")) do
      {:ok, %{parsed | daily_session: daily_session}}
    end
  end

  defp parse_automation(%{"dailySession" => _}), do: :error

  defp parse_automation(
         %{
           "jobName" => job_name,
           "enabled" => enabled,
           "schedule" => schedule,
           "userPrompt" => user_prompt,
           "model" => model,
           "thinkingLevel" => thinking_level
         } = automation
       )
       when is_binary(job_name) and is_boolean(enabled) and is_binary(schedule) and
              is_binary(user_prompt) and is_binary(model) and thinking_level in @thinking_levels do
    can_launch_sub_agents = Map.get(automation, "canLaunchSubAgents", false)

    if is_boolean(can_launch_sub_agents),
      do:
        {:ok,
         %__MODULE__{
           job_name: job_name,
           enabled: enabled,
           schedule: schedule,
           user_prompt: user_prompt,
           daily_session: false,
           model: model,
           thinking_level: thinking_level,
           can_launch_sub_agents: can_launch_sub_agents
         }},
      else: :error
  end

  defp parse_automation(_), do: :error

  defp to_domain(record),
    do:
      struct(__MODULE__, Map.take(record, __struct__() |> Map.keys() |> List.delete(:__struct__)))

  defp notify, do: Phoenix.PubSub.broadcast(WebApp.PubSub, "automations", :changed)

  defp backup(path),
    do:
      if(File.exists?(path),
        do:
          File.rename(path, "#{path}.imported-#{DateTime.utc_now() |> DateTime.to_unix()}.json"),
        else: :ok
      )
end
