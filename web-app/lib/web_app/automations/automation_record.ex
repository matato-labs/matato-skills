defmodule WebApp.Automations.AutomationRecord do
  use Ecto.Schema
  import Ecto.Changeset

  schema "automations" do
    field(:job_name, :string)
    field(:enabled, :boolean, default: true)
    field(:schedule, :string)
    field(:user_prompt, :string)
    field(:daily_session, :boolean, default: false)
    field(:model, :string)
    field(:thinking_level, :string)
    field(:can_launch_sub_agents, :boolean, default: false)
    timestamps(type: :utc_datetime)
  end

  def changeset(record, attributes) do
    record
    |> cast(attributes, [
      :job_name,
      :enabled,
      :schedule,
      :user_prompt,
      :daily_session,
      :model,
      :thinking_level,
      :can_launch_sub_agents
    ])
    |> validate_required([
      :job_name,
      :enabled,
      :schedule,
      :user_prompt,
      :daily_session,
      :model,
      :thinking_level,
      :can_launch_sub_agents
    ])
    |> validate_schedule()
    |> unique_constraint(:job_name)
  end

  defp validate_schedule(changeset) do
    validate_change(changeset, :schedule, fn :schedule, schedule ->
      case Crontab.CronExpression.Parser.parse(schedule, String.split(schedule) |> length() == 6) do
        {:ok, _schedule} -> []
        {:error, _reason} -> [schedule: "is invalid"]
      end
    end)
  end
end
