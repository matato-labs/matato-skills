defmodule WebApp.Sessions.Catalog do
  alias WebApp.Sessions.Workspace

  def workspace_groups(records),
    do: groups(Enum.reject(records, &(&1["source"] in ["automation", "general"])))

  def general_sessions(records) do
    records
    |> Enum.filter(&(&1["source"] == "general"))
    |> Enum.map(&normalize(&1, Workspace.root()))
    |> sort_runs()
  end

  def automation_groups(records, automations) do
    runs =
      records
      |> Enum.filter(&(&1["source"] == "automation"))
      |> Enum.map(&normalize(&1, Workspace.root()))
      |> Enum.group_by(& &1.title)

    automations
    |> Enum.filter(&(&1.enabled and &1.monitor))
    |> Enum.map(fn automation ->
      automation_runs = runs |> Map.get(automation.job_name, []) |> sort_runs()

      %{
        key: automation.id,
        id: automation.id,
        label: automation.job_name,
        count: length(automation_runs),
        status_counts: Enum.frequencies_by(automation_runs, &status_group(&1.status)),
        sessions: automation_runs
      }
    end)
  end

  def automation_runs(records, name) do
    records
    |> Enum.filter(&(&1["source"] == "automation" and &1["name"] == name))
    |> Enum.sort_by(&{&1["updated_at"] || &1["created_at"] || "", &1["id"]}, :desc)
  end

  def groups(records) do
    workspace = Workspace.root()

    records
    |> Enum.map(&normalize(&1, workspace))
    |> Enum.group_by(& &1.group_key)
    |> Enum.map(&group/1)
    |> Enum.sort_by(&{&1.last_activity, &1.label}, :desc)
  end

  defp status_group(status)
       when status in ["starting", "working", "waiting_for_input", "retrying", "compacting"],
       do: :working

  defp status_group("settled"), do: :finished
  defp status_group(_status), do: :failed

  defp normalize(record, workspace) do
    project = canonical_project(record["project"])

    inside_workspace? =
      project == workspace or String.starts_with?(project || "", workspace <> "/")

    {group_key, label} = group_details(project, workspace, inside_workspace?)
    last_activity = record["updated_at"] || record["created_at"] || ""

    %{
      id: record["id"],
      source: record["source"] || "web",
      status: record["status"] || "interrupted",
      title: record["name"] || if(project, do: Path.basename(project), else: "Untitled session"),
      project_root: project,
      project_label: label,
      group_key: group_key,
      last_activity: last_activity
    }
  end

  defp sort_runs(runs), do: Enum.sort_by(runs, &{&1.last_activity, &1.id}, :desc)

  defp group({group_key, sessions}) do
    sessions = Enum.sort_by(sessions, &{&1.last_activity, &1.id}, :desc)

    %{
      key: group_key,
      label: List.first(sessions).project_label,
      count: length(sessions),
      last_activity: List.first(sessions).last_activity,
      sessions: sessions
    }
  end

  defp group_details(project, workspace, true),
    do:
      {project,
       if(project == workspace,
         do: Path.basename(workspace),
         else: Path.relative_to(project, workspace)
       )}

  defp group_details(_project, _workspace, false), do: {:others, "Others"}

  defp canonical_project(nil), do: nil

  defp canonical_project(project) do
    case Workspace.canonical(project) do
      {:ok, path} -> path
      {:error, _reason} -> Path.expand(project)
    end
  end
end
