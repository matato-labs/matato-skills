defmodule WebApp.ProjectSessionCatalog do
  alias WebApp.Workspace

  def workspace_groups(records), do: groups(Enum.reject(records, &(&1["source"] == "automation")))

  def automation_groups(records) do
    records
    |> Enum.filter(&(&1["source"] == "automation" and active?(&1["status"])))
    |> groups()
  end

  def groups(records) do
    workspace = Workspace.root()

    records
    |> Enum.map(&normalize(&1, workspace))
    |> Enum.group_by(& &1.group_key)
    |> Enum.map(&group/1)
    |> Enum.sort_by(&{&1.last_activity, &1.label}, :desc)
  end

  defp active?(status),
    do: status in ["starting", "working", "waiting_for_input", "retrying", "compacting"]

  defp normalize(record, workspace) do
    project = canonical_project(record["project"])

    inside_workspace? =
      project != workspace and String.starts_with?(project || "", workspace <> "/")

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
    do: {project, Path.relative_to(project, workspace)}

  defp group_details(_project, _workspace, false), do: {:others, "Others"}

  defp canonical_project(nil), do: nil

  defp canonical_project(project) do
    case Workspace.canonical(project) do
      {:ok, path} -> path
      {:error, _reason} -> Path.expand(project)
    end
  end
end
