defmodule WebApp.ProjectSessionCatalogTest do
  use ExUnit.Case, async: false

  alias WebApp.ProjectSessionCatalog

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

  test "groups workspace projects and places outside and root sessions in Others", context do
    alpha = Path.join(context.workspace, "alpha")
    beta = Path.join(context.workspace, "team/beta")

    groups =
      ProjectSessionCatalog.groups([
        session("alpha", alpha, "2026-01-01T00:00:00Z"),
        session("beta", beta, "2026-01-03T00:00:00Z"),
        session("outside", context.outside, "2026-01-02T00:00:00Z", "terminal"),
        session("root", context.workspace, "2026-01-04T00:00:00Z")
      ])

    assert Enum.map(groups, & &1.label) == ["Others", "team/beta", "alpha"]
    assert [%{count: 2, sessions: others} | _rest] = groups
    assert Enum.map(others, & &1.id) == ["root", "outside"]
    assert Enum.find(others, &(&1.id == "outside")).source == "terminal"
  end

  test "uses canonical project roots as group keys", context do
    project = Path.join(context.workspace, "alpha")
    alias_path = Path.join(context.workspace, "linked-alpha")
    File.ln_s!(project, alias_path)

    [group] =
      ProjectSessionCatalog.groups([
        session("one", project, "2026-01-01T00:00:00Z"),
        session("two", alias_path, "2026-01-02T00:00:00Z")
      ])

    assert group.label == "alpha"
    assert group.count == 2
    assert group.key == project
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
