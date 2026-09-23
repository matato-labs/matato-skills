defmodule WebApp.Sessions.TranscriptTest do
  use ExUnit.Case, async: false

  alias WebApp.Sessions.Transcript

  setup do
    root = Path.join(Application.fetch_env!(:web_app, :automation_storage_path), "sessions")
    File.mkdir_p!(root)
    path = Path.join(root, "transcript-#{System.unique_integer([:positive])}.jsonl")
    on_exit(fn -> File.rm(path) end)
    %{path: path}
  end

  test "loads messages and tool results from a monitored run", %{path: path} do
    entries = [
      %{"type" => "session", "version" => 3, "id" => "pi-run", "cwd" => "/tmp"},
      %{
        "type" => "message",
        "message" => %{"role" => "user", "content" => "Review it", "timestamp" => 1}
      },
      %{
        "type" => "message",
        "message" => %{
          "role" => "assistant",
          "content" => [
            %{
              "type" => "toolCall",
              "id" => "tool-1",
              "name" => "bash",
              "arguments" => %{"command" => "pwd"}
            }
          ],
          "timestamp" => 2
        }
      },
      %{
        "type" => "message",
        "message" => %{
          "role" => "toolResult",
          "toolCallId" => "tool-1",
          "toolName" => "bash",
          "content" => [%{"type" => "text", "text" => "/tmp"}],
          "isError" => false,
          "timestamp" => 3
        }
      },
      %{
        "type" => "message",
        "message" => %{
          "role" => "assistant",
          "content" => [%{"type" => "text", "text" => "Finished"}],
          "timestamp" => 4
        }
      }
    ]

    File.write!(path, Enum.map_join(entries, "\n", &Jason.encode!/1) <> "\n")

    assert {:ok, transcript} = Transcript.load(metadata(path, "settled"))
    assert transcript.status == :settled

    assert Enum.map(transcript.messages, & &1["role"]) == [
             "user",
             "assistant",
             "toolResult",
             "assistant"
           ]

    assert transcript.tools["tool-1"].result == %{
             "content" => [%{"type" => "text", "text" => "/tmp"}]
           }
  end

  test "rejects transcripts outside automation storage" do
    path = Path.join(System.tmp_dir!(), "outside-#{System.unique_integer([:positive])}.jsonl")
    File.write!(path, "{}\n")
    on_exit(fn -> File.rm(path) end)

    assert {:error, :unavailable} = Transcript.load(metadata(path, "failed"))
  end

  defp metadata(path, status) do
    %{"source" => "automation", "session_file" => path, "status" => status}
  end
end
