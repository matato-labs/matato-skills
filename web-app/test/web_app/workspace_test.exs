defmodule WebApp.Sessions.WorkspaceTest do
  use ExUnit.Case, async: false

  alias WebApp.Sessions.Workspace

  setup do
    previous = Application.fetch_env!(:web_app, :workspace)
    root = Path.join(System.tmp_dir!(), "workspace-#{System.unique_integer([:positive])}")
    outside = Path.join(System.tmp_dir!(), "outside-#{System.unique_integer([:positive])}")
    prefixed_outside = root <> "-outside"
    File.mkdir_p!(Path.join(root, "project"))
    File.mkdir_p!(outside)
    File.mkdir_p!(prefixed_outside)
    File.ln_s!(outside, Path.join(root, "escape"))
    Application.put_env(:web_app, :workspace, root)

    on_exit(fn ->
      Application.put_env(:web_app, :workspace, previous)
      File.rm_rf!(root)
      File.rm_rf!(outside)
      File.rm_rf!(prefixed_outside)
    end)

    %{root: root}
  end

  test "allows directories and rejects traversal and symlink escapes", %{root: root} do
    assert Workspace.resolve("project") |> String.ends_with?("/project")
    assert_raise ArgumentError, fn -> Workspace.resolve("../") end
    assert_raise ArgumentError, fn -> Workspace.resolve("../#{Path.basename(root)}-outside") end
    assert_raise ArgumentError, fn -> Workspace.resolve("escape") end
    assert Workspace.directories() == [%{name: "project", path: "project"}]
  end
end
