defmodule WebApp.ExecutionTest do
  use ExUnit.Case, async: false

  alias WebApp.Execution

  setup do
    directory =
      Path.join(System.tmp_dir!(), "execution-#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)
    old_path = System.get_env("PATH")
    old_storage = Application.get_env(:web_app, :automation_storage_path)
    System.put_env("PATH", "#{directory}:#{old_path}")
    Application.put_env(:web_app, :automation_storage_path, Path.join(directory, "config"))

    on_exit(fn ->
      System.put_env("PATH", old_path)
      Application.put_env(:web_app, :automation_storage_path, old_storage)
      File.rm_rf!(directory)
    end)

    %{directory: directory}
  end

  test "RPC rejection never calls post-script", %{directory: directory} do
    assert_failure(
      directory,
      "'{\"type\":\"response\",\"success\":false,\"error\":\"rejected\"}'",
      "rejected"
    )
  end

  test "assistant error and aborted stop reasons never call post-script", %{directory: directory} do
    for reason <- ["error", "aborted"] do
      event =
        "'{\"type\":\"message_end\",\"message\":{\"role\":\"assistant\",\"stopReason\":\"#{reason}\",\"errorMessage\":\"model failed\",\"content\":[]}}'"

      assert_failure(directory, event, "model failed")
    end
  end

  test "required assistant success gates the post-script", %{directory: directory} do
    marker = Path.join(directory, "post-marker")
    executable(directory, "bun", "#!/bin/sh\ntouch #{marker}\n")

    executable(
      directory,
      "pi",
      "#!/bin/sh\nIFS= read -r line\nprintf '%s\\n' '{\"type\":\"agent_settled\"}'\n"
    )

    File.mkdir_p!(Path.join(directory, "scripts"))
    File.write!(Path.join(directory, "scripts/postScript.ts"), "post")

    assert {:error, "Pi settled without a successful assistant turn"} =
             Execution.run(
               %{name: "review", prompt: "Review work", require_success: true},
               {directory, "work"}
             )

    refute File.exists?(marker)
  end

  test "agent-end failure event never calls post-script", %{directory: directory} do
    event =
      ~s('{"type":"agent_end","willRetry":false,"messages":[{"role":"assistant","stopReason":"error","errorMessage":"provider failed","content":[]}]}')

    assert_failure(directory, event, "provider failed")
  end

  test "successful execution uses Pi defaults and runs post-script", %{directory: directory} do
    args = Path.join(directory, "args")
    cwd = Path.join(directory, "cwd")
    marker = Path.join(directory, "post-marker")
    executable(directory, "bun", "#!/bin/sh\ntouch #{marker}\n")

    executable(
      directory,
      "pi",
      "#!/bin/sh\nprintf '%s\\n' \"$@\" > #{args}\npwd > #{cwd}\nIFS= read -r line\nprintf '%s\\n' '{\"type\":\"message_end\",\"message\":{\"role\":\"assistant\",\"stopReason\":\"stop\",\"content\":[{\"type\":\"text\",\"text\":\"done\"}]}}' '{\"type\":\"agent_settled\"}'\n"
    )

    File.mkdir_p!(Path.join(directory, "scripts"))
    File.write!(Path.join(directory, "scripts/postScript.ts"), "post")

    assert {:ok, "done"} =
             Execution.run(
               %{
                 name: "review",
                 prompt: "Review work",
                 skill_name: "review",
                 require_success: true
               },
               {directory, "work"}
             )

    assert File.exists?(marker)
    refute File.read!(args) =~ "--model"
    refute File.read!(args) =~ "--thinking"
    assert File.read!(cwd) |> String.trim() == Path.join(directory, "config")
  end

  test "empty pre-script avoids Pi and post-script", %{directory: directory} do
    marker = Path.join(directory, "pi-marker")
    executable(directory, "bun", "#!/bin/sh\nexit 0\n")
    executable(directory, "pi", "#!/bin/sh\ntouch #{marker}\n")
    skill = skill(directory)
    assert :skip = Execution.prepare("execution-test-#{Path.basename(directory)}")
    refute File.exists?(marker)
    refute File.exists?(Path.join(skill, "post-marker"))
  end

  defp assert_failure(directory, event, message) do
    marker = Path.join(directory, "post-marker")
    executable(directory, "bun", "#!/bin/sh\ntouch #{marker}\n")

    executable(
      directory,
      "pi",
      "#!/bin/sh\nIFS= read -r line\nprintf '%s\\n' #{event} '{\"type\":\"agent_settled\"}'\n"
    )

    File.mkdir_p!(Path.join(directory, "scripts"))
    File.write!(Path.join(directory, "scripts/postScript.ts"), "post")

    assert {:error, reason} =
             Execution.run(%{name: "review", prompt: "Review work"}, {directory, "work"})

    assert reason =~ message
    refute File.exists?(marker)
  end

  defp skill(directory) do
    name = "execution-test-#{Path.basename(directory)}"
    path = Path.join([System.user_home!(), ".pi", "agent", "skills", name])
    File.mkdir_p!(Path.join(path, "scripts"))
    File.write!(Path.join(path, "scripts/preScript.ts"), "// empty")
    File.write!(Path.join(path, "scripts/postScript.ts"), "// no post")
    ExUnit.Callbacks.on_exit(fn -> File.rm_rf!(path) end)
    path
  end

  defp executable(directory, name, body) do
    path = Path.join(directory, name)
    File.write!(path, body)
    File.chmod!(path, 0o755)
  end
end
