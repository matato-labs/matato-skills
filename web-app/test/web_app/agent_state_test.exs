defmodule WebApp.Sessions.StateTest do
  use ExUnit.Case, async: true

  alias WebApp.Sessions.State

  test "assembles indexed text and thinking, and settles only on agent_settled" do
    state = State.new()
    state = State.apply(state, %{"type" => "agent_start"})

    state =
      State.apply(state, %{
        "type" => "message_start",
        "message" => %{"role" => "assistant"}
      })

    state =
      State.apply(state, %{
        "type" => "message_update",
        "assistantMessageEvent" => %{
          "type" => "text_delta",
          "contentIndex" => 1,
          "delta" => "world"
        }
      })

    state =
      State.apply(state, %{
        "type" => "message_update",
        "assistantMessageEvent" => %{
          "type" => "text_delta",
          "contentIndex" => 0,
          "delta" => "Hello "
        }
      })

    state =
      State.apply(state, %{
        "type" => "message_update",
        "assistantMessageEvent" => %{
          "type" => "thinking_delta",
          "contentIndex" => 2,
          "delta" => "private"
        }
      })

    assert State.partial_text(state) == "Hello world"
    assert State.partial_thinking(state) == "private"
    assert state.status == :working

    state = State.apply(state, %{"type" => "agent_end", "willRetry" => false})
    assert state.status == :working

    state = State.apply(state, %{"type" => "agent_settled"})
    assert state.status == :settled
  end

  test "buffers tool-call arguments and replaces accumulated tool progress" do
    state = State.new()

    state =
      State.apply(state, %{
        "type" => "message_update",
        "assistantMessageEvent" => %{
          "type" => "toolcall_start",
          "contentIndex" => 0,
          "id" => "call-1",
          "toolName" => "bash"
        }
      })

    state =
      State.apply(state, %{
        "type" => "message_update",
        "assistantMessageEvent" => %{
          "type" => "toolcall_delta",
          "contentIndex" => 0,
          "delta" => "{\"command\":"
        }
      })

    state =
      State.apply(state, %{
        "type" => "tool_execution_update",
        "toolCallId" => "call-1",
        "partialResult" => %{"content" => [%{"type" => "text", "text" => "new"}]}
      })

    assert state.tools["call-1"].args == "{\"command\":"
    assert state.tools["call-1"].result["content"] |> hd() |> Map.fetch!("text") == "new"

    state =
      State.apply(state, %{
        "type" => "tool_execution_update",
        "toolCallId" => "call-1",
        "partialResult" => %{"content" => [%{"type" => "text", "text" => "latest"}]}
      })

    assert state.tools["call-1"].result["content"] |> hd() |> Map.fetch!("text") == "latest"
    assert state.tool_order == ["call-1"]
  end

  test "keeps Pi queue updates for reconnecting clients and clears processed messages" do
    state =
      State.apply(State.new(), %{
        "type" => "queue_update",
        "steering" => ["Change the approach"],
        "followUp" => ["Run the tests"]
      })

    assert state.queue == %{
             "steering" => ["Change the approach"],
             "followUp" => ["Run the tests"]
           }

    state = State.apply(state, %{"type" => "queue_update", "followUp" => []})

    assert state.queue == %{"steering" => ["Change the approach"], "followUp" => []}
  end

  test "drops malformed live event values without corrupting the session snapshot" do
    state =
      State.new()
      |> State.apply(%{"type" => "queue_update", "steering" => %{}, "followUp" => ["Safe", 1]})
      |> State.apply(%{
        "type" => "message_update",
        "assistantMessageEvent" => %{
          "type" => "text_delta",
          "contentIndex" => %{},
          "delta" => %{}
        }
      })
      |> State.apply(%{
        "type" => "tool_execution_update",
        "toolCallId" => %{},
        "partialResult" => %{"content" => [nil]}
      })
      |> State.apply(%{"type" => "extension_ui_request", "method" => "input", "id" => %{}})
      |> State.apply(%{"type" => "extension_error", "error" => %{}})

    assert state.queue == %{"steering" => [], "followUp" => ["Safe"]}
    assert state.partial == %{blocks: %{}}
    assert state.tools == %{}
    assert state.dialog == nil
    assert state.error == nil
  end

  test "does not store a tool with a malformed identifier" do
    state =
      State.apply(State.new(), %{
        "type" => "message_update",
        "assistantMessageEvent" => %{
          "type" => "toolcall_start",
          "contentIndex" => 0,
          "id" => %{},
          "toolName" => "bash"
        }
      })

    assert state.tools == %{}
    assert state.tool_order == []
  end

  test "uses message_end as the authoritative completed message" do
    message = %{"role" => "assistant", "content" => [%{"type" => "text", "text" => "Done"}]}
    state = State.apply(State.new(), %{"type" => "message_end", "message" => message})
    assert state.messages == [message]
    assert state.partial == %{blocks: %{}}
  end

  test "discovers the current thinking level" do
    state =
      State.discover(State.new(), %{
        "isStreaming" => false,
        "isCompacting" => false,
        "thinkingLevel" => "high"
      })

    assert state.thinking_level == "high"
  end

  test "retains failed assistant messages after settling and hydrating" do
    message = %{
      "role" => "assistant",
      "content" => [],
      "stopReason" => "error",
      "errorMessage" => "The model is unavailable"
    }

    state =
      State.new()
      |> State.apply(%{"type" => "message_end", "message" => message})
      |> State.apply(%{"type" => "agent_settled"})

    assert state.status == :settled
    assert state.messages == [message]

    assert State.hydrate(State.new(), %{"messages" => state.messages}).messages == [
             message
           ]
  end

  test "hydrates the discovered active status with compaction taking precedence" do
    state =
      State.discover(State.new(), %{"isStreaming" => true, "isCompacting" => true})

    assert State.hydrate(state, %{"messages" => []}).status == :compacting

    state =
      State.discover(State.new(), %{"isStreaming" => true, "isCompacting" => false})

    assert State.hydrate(state, %{"messages" => []}).status == :working
  end

  test "hydrates an interrupted restart without pretending it settled" do
    state = State.new(interrupted: true)
    state = State.discover(state, %{"isStreaming" => false})
    state = State.hydrate(state, %{"messages" => []})
    assert state.status == :interrupted
  end

  test "command rejection does not change run state" do
    state = State.new() |> Map.put(:status, :working)
    assert State.command_error(state, "rejected").status == :working
  end

  test "keeps command discovery failures separate from session errors" do
    state = State.new() |> State.commands_failed("Command discovery failed")
    assert state.commands == []
    assert state.commands_error == "Command discovery failed"
    assert state.error == nil

    state = State.commands_ready(state, [%{"name" => "plan"}])
    assert state.commands == [%{"name" => "plan"}]
    assert state.commands_error == nil
  end

  test "bounds streamed delta and tool output events before fanout" do
    payload = String.duplicate("😀", 30_000)

    event =
      State.cap_event(%{
        "type" => "tool_execution_update",
        "partialResult" => %{"content" => [%{"type" => "text", "text" => payload}]},
        "assistantMessageEvent" => %{"type" => "text_delta", "delta" => payload}
      })

    assert byte_size(get_in(event, ["partialResult", "content", Access.at(0), "text"])) == 24_000
    assert byte_size(get_in(event, ["assistantMessageEvent", "delta"])) == 24_000
  end

  test "keeps complete warm reconnect snapshots" do
    long_text = String.duplicate("x", 30_000)

    state =
      Enum.reduce(1..210, State.new(), fn index, result ->
        State.apply(result, %{
          "type" => "message_end",
          "message" => %{"role" => "assistant", "content" => long_text <> to_string(index)}
        })
      end)

    assert length(state.messages) == 210
    assert byte_size(hd(state.messages)["content"]) == 24_000
  end

  test "retains every tool record from a long persisted session" do
    messages =
      Enum.map(1..210, fn index ->
        %{
          "role" => "assistant",
          "content" => [
            %{
              "type" => "toolCall",
              "id" => "call-#{index}",
              "name" => "bash",
              "arguments" => "{}"
            }
          ]
        }
      end)

    state = State.hydrate(State.new(), %{"messages" => messages})

    assert length(state.messages) == 210
    assert length(state.tool_order) == 210
    assert Map.has_key?(state.tools, "call-1")
    assert Map.has_key?(state.tools, "call-210")
  end

  test "retains every tool record from a long live session" do
    state =
      Enum.reduce(1..102, State.new(), fn index, state ->
        State.apply(state, %{
          "type" => "tool_execution_start",
          "toolCallId" => "call-#{index}",
          "toolName" => "bash",
          "args" => "{}"
        })
      end)

    assert length(state.tool_order) == 102
    assert Map.has_key?(state.tools, "call-1")
    assert Map.has_key?(state.tools, "call-102")
  end
end
