defmodule WebApp.Automation do
  @enforce_keys [
    :job_name,
    :enabled,
    :schedule,
    :user_prompt,
    :daily_session,
    :can_overlap,
    :model,
    :thinking_level
  ]
  defstruct [
    :job_name,
    :enabled,
    :schedule,
    :user_prompt,
    :daily_session,
    :can_overlap,
    :model,
    :thinking_level
  ]

  @thinking_levels ~w(off minimal low medium high xhigh max)

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

  defp parse(automations) do
    automations
    |> Enum.reduce_while({:ok, []}, fn automation, {:ok, parsed} ->
      case parse_automation(automation) do
        {:ok, automation} -> {:cont, {:ok, [automation | parsed]}}
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

  defp parse_automation(%{"dailySession" => _daily_session}), do: :error

  defp parse_automation(%{"canOverlap" => can_overlap} = automation)
       when is_boolean(can_overlap) do
    with {:ok, parsed} <- parse_automation(Map.delete(automation, "canOverlap")) do
      {:ok, %{parsed | can_overlap: can_overlap}}
    end
  end

  defp parse_automation(%{"canOverlap" => _can_overlap}), do: :error

  defp parse_automation(%{
         "jobName" => job_name,
         "enabled" => enabled,
         "schedule" => schedule,
         "userPrompt" => user_prompt,
         "model" => model,
         "thinkingLevel" => thinking_level
       })
       when is_binary(job_name) and is_boolean(enabled) and is_binary(schedule) and
              is_binary(user_prompt) and is_binary(model) and thinking_level in @thinking_levels do
    {:ok,
     %__MODULE__{
       job_name: job_name,
       enabled: enabled,
       schedule: schedule,
       user_prompt: user_prompt,
       daily_session: false,
       can_overlap: false,
       model: model,
       thinking_level: thinking_level
     }}
  end

  defp parse_automation(_automation), do: :error
end
