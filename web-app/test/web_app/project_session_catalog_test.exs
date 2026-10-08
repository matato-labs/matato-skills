defmodule WebApp.Sessions.CatalogTest do
  use ExUnit.Case, async: false

  alias WebApp.Sessions.Catalog

  setup do
    workspace = Path.join(System.tmp_dir!(), "workspace-#{System.unique_integer([:positive])}")
    outside = Path.join(System.tmp_dir!(), "outside-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(workspace, "alpha"))
    File.mkdir_p!(Path.join(workspace, "team/beta"))
    File.mkdir_p!(outside)
    previous = Application.fetch_env!(:web_app, :workspace)
    Application.put_env(:web_app, :workspace, workspace)

    on_exit(fn ->
      Application.put_env(:web_app, :workspace, previous)
      File.rm_rf!(workspace)
      File.rm_rf!(outside)
    end)

    %{workspace: workspace, outside: outside}
  end

  test "groups workspace projects and root separately from outside sessions", context do
    alpha = Path.join(context.workspace, "alpha")
    beta = Path.join(context.workspace, "team/beta")

    groups =
      Catalog.groups([
        session("alpha", alpha, "2026-01-01T00:00:00Z"),
        session("beta", beta, "2026-01-03T00:00:00Z"),
        session("outside", context.outside, "2026-01-02T00:00:00Z", "terminal"),
        session("root", context.workspace, "2026-01-04T00:00:00Z")
      ])

    assert Enum.map(groups, & &1.label) == [
             Path.basename(context.workspace),
             "team/beta",
             "Others",
             "alpha"
           ]

    assert [%{id: "root"}] = Enum.find(groups, &(&1.key == context.workspace)).sessions
    assert [%{id: "outside"}] = Enum.find(groups, &(&1.label == "Others")).sessions
  end

  test "general sessions are separate from historical workspace root sessions", context do
    records = [
      session("general", context.outside, "2026-01-02T00:00:00Z", "general"),
      session("old-bot", context.workspace, "2026-01-01T00:00:00Z", "bot_chat")
    ]

    assert [%{sessions: [%{id: "old-bot"}]}] = Catalog.workspace_groups(records)
    assert [%{id: "general", source: "general"}] = Catalog.general_sessions(records)
  end

  test "uses canonical project roots as group keys", context do
    project = Path.join(context.workspace, "alpha")
    alias_path = Path.join(context.workspace, "linked-alpha")
    File.ln_s!(project, alias_path)

    [group] =
      Catalog.groups([
        session("one", project, "2026-01-01T00:00:00Z"),
        session("two", alias_path, "2026-01-02T00:00:00Z")
      ])

    assert group.label == "alpha"
    assert group.count == 2
    assert group.key == project
  end

  test "separates workspace sessions and keeps automation run history", context do
    sessions = [
      session("workspace", Path.join(context.workspace, "alpha"), "2026-01-01T00:00:00Z"),
      session("running", context.workspace, "2026-01-02T00:00:00Z", "automation")
      |> Map.merge(%{"name" => "daily", "status" => "working"}),
      session("finished", context.workspace, "2026-01-03T00:00:00Z", "automation")
      |> Map.put("name", "daily"),
      session("failed", context.workspace, "2026-01-04T00:00:00Z", "automation")
      |> Map.merge(%{"name" => "daily", "status" => "failed"})
    ]

    assert [%{sessions: [%{id: "workspace"}]}] = Catalog.workspace_groups(sessions)

    assert [
             %{
               label: "daily",
               status_counts: %{working: 1, finished: 1, failed: 1},
               sessions: [%{id: "failed"}, %{id: "finished"}, %{id: "running"}]
             }
           ] =
             Catalog.automation_groups(sessions, [
               %{id: 7, job_name: "daily", enabled: true, monitor: true},
               %{id: 8, job_name: "unmonitored", enabled: true, monitor: false}
             ])
  end

  test "normalizes missing metadata and preserves explicit empty values", context do
    project = Path.join(context.workspace, "alpha")

    [group] =
      Catalog.groups([
        %{"id" => "project", "project" => project, "created_at" => "created"},
        %{
          "id" => "named",
          "project" => project,
          "name" => "Custom title",
          "updated_at" => "updated",
          "created_at" => "created"
        },
        %{
          "id" => "empty",
          "project" => project,
          "name" => "",
          "source" => "",
          "status" => "",
          "updated_at" => "",
          "created_at" => "created"
        }
      ])

    assert Enum.map(group.sessions, & &1.id) == ["named", "project", "empty"]
    assert Enum.map(group.sessions, & &1.title) == ["Custom title", "alpha", ""]
    assert Enum.map(group.sessions, & &1.last_activity) == ["updated", "created", ""]
    assert Enum.map(group.sessions, & &1.source) == ["web", "web", ""]
    assert Enum.map(group.sessions, & &1.status) == ["interrupted", "interrupted", ""]
  end

  test "normalizes projectless sessions without losing their names" do
    [group] = Catalog.groups([%{"id" => "untitled"}, %{"id" => "named", "name" => "Named"}])

    assert group.key == :others
    assert group.label == "Others"
    assert Enum.map(group.sessions, & &1.title) == ["Untitled session", "Named"]
    assert Enum.all?(group.sessions, &(&1.project_root == nil and &1.last_activity == ""))
  end

  defp session(id, project, created_at, source \\ "web") do
    %{
      "id" => id,
      "name" => id,
      "project" => project,
      "source" => source,
      "status" => "settled",
      "created_at" => created_at
    }
  end
end
