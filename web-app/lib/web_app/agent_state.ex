defmodule WebApp.AgentState do
  @moduledoc "Semantic browser snapshot assembled from Pi RPC events."

  import Kernel, except: [apply: 2]

  @active_statuses [:working, :waiting_for_input, :retrying, :compacting]
  @max_messages 200
  @max_text_bytes 24_000
  @max_tools 100

  def new(options \\ []) do
    %{
      status: :starting,
      discovered_status: :settled,
      interrupted?: Keyword.get(options, :interrupted, false),
      messages: [],
      partial: %{blocks: %{}},
      tools: %{},
      tool_order: [],
      queue: %{"steering" => [], "followUp" => []},
      dialog: nil,
      notices: [],
      model: nil,
      session_file: nil,
      session_id: nil,
      error: nil,
      commands: [],
      commands_error: nil,
      run_started_at: nil,
      last_run_duration: nil
    }
  end

  def cap_event(event), do: cap_event_value(event)

  def apply(state, {:event, event}), do: apply(state, event)
  def apply(state, :dialog_cleared), do: clear_dialog(state)
  def apply(state, {:commands_ready, commands}), do: commands_ready(state, commands)
  def apply(state, {:commands_failed, error}), do: commands_failed(state, error)
  def apply(state, {:command_error, error}), do: command_error(state, error)
  def apply(state, {:exit, error}), do: exit(state, error)
  def apply(state, {:hint, _event}), do: state
  def apply(state, {:owner, _owner}), do: state

  def apply(state, %{"type" => "agent_start"}),
    do: %{state | status: :working, interrupted?: false, run_started_at: now()}

  def apply(state, %{"type" => "agent_settled"}) do
    duration = if state.run_started_at, do: now() - state.run_started_at, else: nil

    %{
      state
      | status: :settled,
        partial: empty_partial(),
        dialog: nil,
        error: nil,
        run_started_at: nil,
        last_run_duration: duration
    }
  end

  def apply(state, %{"type" => "compaction_start"}), do: %{state | status: :compacting}
  def apply(state, %{"type" => "auto_retry_start"}), do: %{state | status: :retrying}

  def apply(state, %{"type" => type})
      when type in ["summarization_retry_scheduled", "summarization_retry_attempt_start"],
      do: %{state | status: :retrying}

  def apply(state, %{"type" => "queue_update"} = event) do
    queue = Map.take(event, ["steering", "followUp"])
    %{state | queue: Map.merge(state.queue, queue)}
  end

  def apply(state, %{"type" => "message_start", "message" => %{"role" => "assistant"}}),
    do: %{state | partial: empty_partial()}

  def apply(state, %{
        "type" => "message_update",
        "assistantMessageEvent" => %{"contentIndex" => index} = event
      }) do
    update_partial(state, index, event)
  end

  def apply(state, %{"type" => "message_end", "message" => message}) do
    messages = (state.messages ++ [cap_message(message)]) |> Enum.take(-@max_messages)
    %{state | messages: messages, partial: empty_partial()}
  end

  def apply(state, %{"type" => "tool_execution_start", "toolCallId" => id} = event) do
    put_tool(state, id, %{
      id: id,
      name: event["toolName"],
      args: event["args"],
      result: nil,
      status: :running,
      error: false
    })
  end

  def apply(state, %{"type" => "tool_execution_update", "toolCallId" => id} = event) do
    update_tool(state, id, event, %{
      result: cap_result(event["partialResult"]),
      status: :running,
      error: false
    })
  end

  def apply(state, %{"type" => "tool_execution_end", "toolCallId" => id} = event) do
    update_tool(state, id, event, %{
      result: cap_result(event["result"]),
      status: :done,
      error: event["isError"] || false
    })
  end

  def apply(state, %{"type" => "extension_ui_request", "method" => method} = request)
      when method in ["select", "confirm", "input", "editor"],
      do: %{state | dialog: request, status: :waiting_for_input}

  def apply(state, %{"type" => "extension_ui_request", "method" => "notify"} = request),
    do: update_in(state.notices, &[request | Enum.take(&1, 4)])

  def apply(state, %{"type" => "extension_error", "error" => error}),
    do: %{state | error: error}

  def apply(state, _event), do: state

  def hydrate(state, %{"messages" => messages}) do
    status = if state.interrupted?, do: :interrupted, else: state.discovered_status
    tools_state = Enum.reduce(messages, %{state | tools: %{}, tool_order: []}, &hydrate_tool/2)

    %{
      tools_state
      | status: status,
        messages: messages |> Enum.take(-@max_messages) |> Enum.map(&cap_message/1)
    }
  end

  def discover(state, data) do
    discovered_status =
      cond do
        data["isCompacting"] -> :compacting
        data["isStreaming"] -> :working
        true -> :settled
      end

    %{
      state
      | discovered_status: discovered_status,
        model: data["model"],
        session_file: data["sessionFile"],
        session_id: data["sessionId"]
    }
  end

  def partial_text(state) do
    state.partial.blocks
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.filter(fn {_index, block} -> block.type == :text end)
    |> Enum.map_join(&elem(&1, 1).content)
  end

  def partial_thinking(state) do
    state.partial.blocks
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.filter(fn {_index, block} -> block.type == :thinking end)
    |> Enum.map_join(&elem(&1, 1).content)
  end

  def clear_dialog(state), do: %{state | dialog: nil, status: :working}
  def command_error(state, error), do: %{state | error: error}
  def commands_ready(state, commands), do: %{state | commands: commands, commands_error: nil}
  def commands_failed(state, error), do: %{state | commands: [], commands_error: error}

  def exit(state, error) do
    status = if state.status in @active_statuses, do: :interrupted, else: :failed
    %{state | status: status, error: error}
  end

  defp now, do: System.monotonic_time(:millisecond)
  defp empty_partial, do: %{blocks: %{}}

  defp update_partial(state, index, %{"type" => type} = event) do
    case type do
      "text_start" -> put_block(state, index, :text, "")
      "text_delta" -> append_block(state, index, :text, event["delta"])
      "text_end" -> put_block(state, index, :text, event["content"])
      "thinking_start" -> put_block(state, index, :thinking, "")
      "thinking_delta" -> append_block(state, index, :thinking, event["delta"])
      "thinking_end" -> put_block(state, index, :thinking, event["content"])
      "toolcall_start" -> put_preparing_tool(state, index, event)
      "toolcall_delta" -> append_tool_arguments(state, index, event["delta"])
      "toolcall_end" -> finish_preparing_tool(state, index, event["toolCall"])
      _ -> state
    end
  end

  defp put_block(state, index, type, content),
    do: put_in(state.partial.blocks[index], %{type: type, content: cap_text(content || "")})

  defp append_block(state, index, type, delta) do
    block = state.partial.blocks[index] || %{type: type, content: ""}
    content = cap_text(block.content <> (delta || ""))
    put_in(state.partial.blocks[index], %{block | content: content})
  end

  defp put_preparing_tool(state, index, event) do
    id = event["id"]
    state = put_block(state, index, :tool_call, id)

    put_tool(state, id, %{
      id: id,
      name: event["toolName"],
      args: "",
      result: nil,
      status: :preparing,
      error: false
    })
  end

  defp append_tool_arguments(state, index, delta) do
    with %{content: id} <- state.partial.blocks[index],
         %{args: args} = tool when is_binary(args) <- state.tools[id] do
      put_in(state.tools[id], %{tool | args: cap_text(args <> (delta || ""))})
    else
      _ -> state
    end
  end

  defp finish_preparing_tool(state, index, call) do
    id = call["id"] || get_in(state, [:partial, :blocks, index, :content])

    if id && state.tools[id] do
      put_tool(state, id, %{state.tools[id] | name: call["name"], args: call["arguments"]})
    else
      state
    end
  end

  defp update_tool(state, id, event, updates) do
    tool = state.tools[id] || %{id: id, name: event["toolName"], args: event["args"]}
    put_tool(state, id, Map.merge(tool, updates))
  end

  defp put_tool(state, id, tool) do
    order = if id in state.tool_order, do: state.tool_order, else: state.tool_order ++ [id]
    order = Enum.take(order, -@max_tools)

    %{
      state
      | tools: state.tools |> Map.put(id, cap_tool(tool)) |> Map.take(order),
        tool_order: order
    }
  end

  defp cap_tool(tool) do
    args =
      if is_binary(tool.args), do: tool.args, else: inspect(tool.args, pretty: true, limit: 100)

    %{tool | args: cap_text(args)}
  end

  defp cap_result(%{"content" => content}) when is_list(content) do
    text =
      content
      |> Enum.filter(&(&1["type"] == "text" and is_binary(&1["text"])))
      |> Enum.map_join("\n", & &1["text"])
      |> cap_text()

    %{"content" => [%{"type" => "text", "text" => text}]}
  end

  defp cap_result(_result), do: nil

  defp hydrate_tool(%{"role" => "assistant", "content" => content}, state)
       when is_list(content) do
    content
    |> Enum.filter(&(&1["type"] == "toolCall"))
    |> Enum.reduce(state, fn call, result ->
      put_tool(result, call["id"], %{
        id: call["id"],
        name: call["name"],
        args: call["arguments"],
        result: nil,
        status: :done,
        error: false
      })
    end)
  end

  defp hydrate_tool(%{"role" => "toolResult", "toolCallId" => id} = message, state) do
    tool = state.tools[id] || %{id: id, name: message["toolName"], args: %{}}

    put_tool(
      state,
      id,
      Map.merge(tool, %{
        result: cap_result(message),
        status: :done,
        error: message["isError"] || false
      })
    )
  end

  defp hydrate_tool(_message, state), do: state

  defp cap_event_value(value) when is_binary(value), do: cap_text(value)
  defp cap_event_value(value) when is_list(value), do: Enum.map(value, &cap_event_value/1)

  defp cap_event_value(value) when is_map(value) do
    Map.new(value, fn {key, item} -> {key, cap_event_value(item)} end)
  end

  defp cap_event_value(value), do: value

  defp cap_message(%{"content" => content} = message) when is_binary(content),
    do: Map.put(message, "content", cap_text(content))

  defp cap_message(%{"content" => content} = message) when is_list(content) do
    content =
      Enum.flat_map(content, fn
        %{"type" => "text", "text" => text} = block when is_binary(text) ->
          [Map.put(block, "text", cap_text(text))]

        %{"type" => "thinking", "thinking" => text} = block when is_binary(text) ->
          [Map.put(block, "thinking", cap_text(text))]

        %{"type" => "toolCall"} = block ->
          [
            Map.update(
              block,
              "arguments",
              "",
              &(&1 |> inspect(pretty: true, limit: 100) |> cap_text())
            )
          ]

        _block ->
          []
      end)

    Map.put(message, "content", content)
  end

  defp cap_message(message), do: message
  defp cap_text(text), do: String.byte_slice(text, 0, @max_text_bytes)
end
