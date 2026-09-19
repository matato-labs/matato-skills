defmodule WebAppWeb.AutomationController do
  use WebAppWeb, :controller

  alias WebApp.Automations

  def index(conn, _params), do: json(conn, %{automations: Enum.map(Automations.list(), &data/1)})

  def show(conn, %{"id" => id}) do
    with {:ok, automation_id} <- parse_id(id),
         %Automations{} = automation <- Automations.get(automation_id) do
      json(conn, %{automation: data(automation)})
    else
      _ -> not_found(conn)
    end
  end

  def create(conn, params) do
    case Automations.create(params) do
      {:ok, automation} -> conn |> put_status(:created) |> json(%{automation: data(automation)})
      {:error, changeset} -> invalid(conn, changeset)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, automation_id} <- parse_id(id) do
      case Automations.update(automation_id, Map.delete(params, "id")) do
        {:ok, automation} -> json(conn, %{automation: data(automation)})
        {:error, :not_found} -> not_found(conn)
        {:error, changeset} -> invalid(conn, changeset)
      end
    else
      _ -> not_found(conn)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, automation_id} <- parse_id(id) do
      case Automations.delete(automation_id) do
        {:ok, _automation} -> send_resp(conn, :no_content, "")
        {:error, :not_found} -> not_found(conn)
      end
    else
      _ -> not_found(conn)
    end
  end

  defp parse_id(id) do
    case Integer.parse(id) do
      {value, ""} -> {:ok, value}
      _ -> :error
    end
  end

  defp data(automation) do
    Map.take(automation, [
      :id,
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
  end

  defp invalid(conn, changeset) do
    errors = Ecto.Changeset.traverse_errors(changeset, fn {message, _options} -> message end)
    conn |> put_status(:unprocessable_entity) |> json(%{errors: errors})
  end

  defp not_found(conn),
    do: conn |> put_status(:not_found) |> json(%{error: "Automation not found"})
end
