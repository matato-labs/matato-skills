defmodule WebApp.Automations.Record do
  use Ecto.Schema
  import Ecto.Changeset

  schema "automations" do
    field(:bot_id, :binary_id)
    field(:job_name, :string)
    field(:enabled, :boolean, default: true)
    field(:schedule, :string)
    field(:user_prompt, :string)
    field(:daily_session, :boolean, default: false)
    field(:can_overlap, :boolean, default: false)
    field(:model, :string)
    field(:thinking_level, :string)
    field(:can_launch_sub_agents, :boolean, default: false)
    field(:monitor, :boolean, default: false)
    field(:use_skill, :boolean, default: false)
    timestamps(type: :utc_datetime)
  end

  def changeset(record, attributes) do
    record
    |> cast(attributes, [
      :bot_id,
      :job_name,
      :enabled,
      :schedule,
      :user_prompt,
      :daily_session,
      :can_overlap,
      :model,
      :thinking_level,
      :can_launch_sub_agents,
      :monitor,
      :use_skill
    ])
    |> validate_required([
      :job_name,
      :enabled,
      :schedule,
      :user_prompt,
      :daily_session,
      :can_overlap,
      :model,
      :thinking_level,
      :can_launch_sub_agents,
      :monitor,
      :use_skill
    ])
    |> validate_schedule()
    |> validate_bot_session()
    |> unique_constraint(:job_name)
    |> foreign_key_constraint(:bot_id)
  end

  defp validate_bot_session(changeset) do
    if get_field(changeset, :bot_id) && get_field(changeset, :daily_session),
      do: add_error(changeset, :daily_session, "cannot be enabled for bot-owned automations"),
      else: changeset
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
