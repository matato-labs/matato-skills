defmodule WebApp.Automations do
  use Boundary,
    top_level?: true,
    deps: [WebApp.Data, WebApp.Execution, WebApp.Sessions],
    exports: []

  import Ecto.Query

  alias WebApp.Automations.Record
  alias WebApp.Data.Repo

  def child_specs, do: [WebApp.Automations.Scheduler, WebApp.Automations.Subscription]

  def subscribe, do: Phoenix.PubSub.subscribe(WebApp.PubSub, "automations")
  def run(automation), do: Task.start(fn -> WebApp.Automations.Runner.run(automation) end)

  @enforce_keys [
    :job_name,
    :enabled,
    :schedule,
    :user_prompt,
    :daily_session,
    :can_overlap,
    :model,
    :thinking_level,
    :use_skill
  ]
  defstruct [
    :id,
    :job_name,
    :enabled,
    :schedule,
    :user_prompt,
    :daily_session,
    :model,
    :thinking_level,
    can_launch_sub_agents: false,
    can_overlap: false,
    monitor: false,
    use_skill: false
  ]

  def list,
    do:
      Repo.all(from(record in Record, order_by: [asc: record.id]))
      |> Enum.map(&to_domain/1)

  def get(id), do: Repo.get(Record, id) |> to_domain()

  def create(attributes), do: persist(%Record{}, attributes, &Repo.insert/1)

  def update(id, attributes) do
    case Repo.get(Record, id) do
      nil -> {:error, :not_found}
      record -> persist(record, attributes, &Repo.update/1)
    end
  end

  def delete(id) do
    case Repo.get(Record, id) do
      nil -> {:error, :not_found}
      record -> Repo.delete(record) |> result() |> notify_result()
    end
  end

  def replace(automations) when is_list(automations) do
    with :ok <- validate_schedules(automations),
         :ok <- validate_job_names(automations),
         {:ok, _} <-
           Repo.transaction(fn ->
             Repo.delete_all(Record)
             Enum.each(automations, &insert/1)
           end) do
      notify()
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert(automation) do
    changeset = Record.changeset(%Record{}, Map.from_struct(automation))

    with {:ok, _record} <- Repo.insert(changeset) do
      :ok
    else
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp persist(record, attributes, operation) do
    changeset = Record.changeset(record, attributes)

    changeset |> operation.() |> result() |> notify_result()
  end

  defp result({:ok, record}), do: {:ok, to_domain(record)}
  defp result({:error, changeset}), do: {:error, changeset}

  defp notify_result({:ok, automation}) do
    notify()
    {:ok, automation}
  end

  defp notify_result(error), do: error

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

  defp to_domain(nil), do: nil

  defp to_domain(record),
    do:
      struct(__MODULE__, Map.take(record, __struct__() |> Map.keys() |> List.delete(:__struct__)))

  defp notify, do: Phoenix.PubSub.broadcast(WebApp.PubSub, "automations", :changed)
end
