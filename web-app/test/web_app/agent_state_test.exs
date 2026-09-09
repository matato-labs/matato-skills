defmodule WebApp.AgentStateTest do
  use ExUnit.Case, async: true

  alias WebApp.AgentState

  test "assembles indexed text and thinking, and settles only on agent_settled" do
    state = AgentState.new()
    state = AgentState.apply(state, %{"type" => "agent_start"})

    state =
      AgentState.apply(state, %{
        "type" => "message_start",
        "message" => %{"role" => "assistant"}
      })

    state =
      AgentState.apply(state, %{
        "type" => "message_update",
        "assistantMessageEvent" => %{
          "type" => "text_delta",
          "contentIndex" => 1,
          "delta" => "world"
        }
      })

    state =
      AgentState.apply(state, %{
        "type" => "message_update",
        "assistantMessageEvent" => %{
          "type" => "text_delta",
          "contentIndex" => 0,
          "delta" => "Hello "
        }
      })

    state =
      AgentState.apply(state, %{
        "type" => "message_update",
        "assistantMessageEvent" => %{
          "type" => "thinking_delta",
          "contentIndex" => 2,
          "delta" => "private"
        }
      })

    assert AgentState.partial_text(state) == "Hello world"
    assert AgentState.partial_thinking(state) == "private"
    assert state.status == :working

    state = AgentState.apply(state, %{"type" => "agent_end", "willRetry" => false})
    assert state.status == :working

    state = AgentState.apply(state, %{"type" => "agent_settled"})
    assert state.status == :settled
  end

  test "buffers tool-call arguments and replaces accumulated tool progress" do
    state = AgentState.new()

    state =
      AgentState.apply(state, %{
        "type" => "message_update",
        "assistantMessageEvent" => %{
          "type" => "toolcall_start",
          "contentIndex" => 0,
          "id" => "call-1",
          "toolName" => "bash"
        }
      })

    state =
      AgentState.apply(state, %{
        "type" => "message_update",
        "assistantMessageEvent" => %{
          "type" => "toolcall_delta",
          "contentIndex" => 0,
          "delta" => "{\"command\":"
        }
      })

    state =
      AgentState.apply(state, %{
        "type" => "tool_execution_update",
        "toolCallId" => "call-1",
        "partialResult" => %{"content" => [%{"type" => "text", "text" => "new"}]}
      })

    assert state.tools["call-1"].args == "{\"command\":"
    assert state.tools["call-1"].result["content"] |> hd() |> Map.fetch!("text") == "new"

    state =
      AgentState.apply(state, %{
        "type" => "tool_execution_update",
        "toolCallId" => "call-1",
        "partialResult" => %{"content" => [%{"type" => "text", "text" => "latest"}]}
      })

    assert state.tools["call-1"].result["content"] |> hd() |> Map.fetch!("text") == "latest"
    assert state.tool_order == ["call-1"]
  end

  test "uses message_end as the authoritative completed message" do
    message = %{"role" => "assistant", "content" => [%{"type" => "text", "text" => "Done"}]}
    state = AgentState.apply(AgentState.new(), %{"type" => "message_end", "message" => message})
    assert state.messages == [message]
    assert state.partial == %{blocks: %{}}
  end

  test "hydrates the discovered active status with compaction taking precedence" do
    state =
      AgentState.discover(AgentState.new(), %{"isStreaming" => true, "isCompacting" => true})

    assert AgentState.hydrate(state, %{"messages" => []}).status == :compacting

    state =
      AgentState.discover(AgentState.new(), %{"isStreaming" => true, "isCompacting" => false})

    assert AgentState.hydrate(state, %{"messages" => []}).status == :working
  end

  test "hydrates an interrupted restart without pretending it settled" do
    state = AgentState.new(interrupted: true)
    state = AgentState.discover(state, %{"isStreaming" => false})
    state = AgentState.hydrate(state, %{"messages" => []})
    assert state.status == :interrupted
  end

  test "command rejection does not change run state" do
    state = AgentState.new() |> Map.put(:status, :working)
    assert AgentState.command_error(state, "rejected").status == :working
  end

  test "keeps warm reconnect snapshots bounded" do
    long_text = String.duplicate("x", 30_000)

    state =
      Enum.reduce(1..210, AgentState.new(), fn index, result ->
        AgentState.apply(result, %{
          "type" => "message_end",
          "message" => %{"role" => "assistant", "content" => long_text <> to_string(index)}
        })
      end)

    assert length(state.messages) == 200
    assert byte_size(hd(state.messages)["content"]) == 24_000
  end
end
