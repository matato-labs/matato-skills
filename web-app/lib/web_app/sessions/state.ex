defmodule WebApp.Sessions.State do
  @moduledoc "Semantic browser snapshot assembled from Pi RPC events."

  import Kernel, except: [apply: 2]

  @active_statuses [:working, :waiting_for_input, :retrying, :compacting]
  @max_text_bytes 24_000

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
      thinking_level: nil,
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
    queue =
      Enum.reduce(["steering", "followUp"], state.queue, fn key, queue ->
        case event[key] do
          nil -> queue
          values when is_list(values) -> Map.put(queue, key, Enum.filter(values, &is_binary/1))
          _value -> Map.put(queue, key, [])
        end
      end)

    %{state | queue: queue}
  end

  def apply(state, %{"type" => "message_start", "message" => %{"role" => "assistant"}}),
    do: %{state | partial: empty_partial()}

  def apply(state, %{
        "type" => "message_update",
        "assistantMessageEvent" => %{"contentIndex" => index} = event
      })
      when is_integer(index) and index >= 0,
      do: update_partial(state, index, event)

  def apply(state, %{"type" => "message_end", "message" => message}) do
    %{state | messages: state.messages ++ cap_message(message), partial: empty_partial()}
  end

  def apply(state, %{"type" => "tool_execution_start", "toolCallId" => id} = event)
      when is_binary(id) do
    put_tool(state, id, %{
      id: id,
      name: event["toolName"],
      args: event["args"],
      result: nil,
      status: :running,
      error: false
    })
  end

  def apply(state, %{"type" => "tool_execution_update", "toolCallId" => id} = event)
      when is_binary(id) do
    update_tool(state, id, event, %{
      result: cap_result(event["partialResult"]),
      status: :running,
      error: false
    })
  end

  def apply(state, %{"type" => "tool_execution_end", "toolCallId" => id} = event)
      when is_binary(id) do
    update_tool(state, id, event, %{
      result: cap_result(event["result"]),
      status: :done,
      error: event["isError"] || false
    })
  end

  def apply(state, %{"type" => "extension_ui_request", "method" => method, "id" => id} = request)
      when method in ["select", "confirm", "input", "editor"] and is_binary(id),
      do: %{state | dialog: request, status: :waiting_for_input}

  def apply(state, %{"type" => "extension_ui_request", "method" => "notify"} = request),
    do: update_in(state.notices, &[request | Enum.take(&1, 4)])

  def apply(state, %{"type" => "extension_error", "error" => error}) when is_binary(error),
    do: %{state | error: error}

  def apply(state, _event), do: state

  def hydrate(state, %{"messages" => messages}) do
    status = if state.interrupted?, do: :interrupted, else: state.discovered_status
    messages = Enum.flat_map(messages, &cap_message/1)
    tools_state = Enum.reduce(messages, %{state | tools: %{}, tool_order: []}, &hydrate_tool/2)
    %{tools_state | status: status, messages: messages}
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
        thinking_level: data["thinkingLevel"],
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

  defp update_partial(state, index, %{"type" => "text_" <> action} = event),
    do: update_text(state, index, action, event)

  defp update_partial(state, index, %{"type" => "thinking_" <> action} = event),
    do: update_thinking(state, index, action, event)

  defp update_partial(state, index, %{"type" => "toolcall_" <> action} = event),
    do: update_tool_call(state, index, action, event)

  defp update_partial(state, _index, _event), do: state

  defp update_text(state, index, "start", _event), do: put_block(state, index, :text, "")

  defp update_text(state, index, "delta", event),
    do: append_block(state, index, :text, event["delta"])

  defp update_text(state, index, "end", event),
    do: put_block(state, index, :text, event["content"])

  defp update_text(state, _index, _action, _event), do: state

  defp update_thinking(state, index, "start", _event), do: put_block(state, index, :thinking, "")

  defp update_thinking(state, index, "delta", event),
    do: append_block(state, index, :thinking, event["delta"])

  defp update_thinking(state, index, "end", event),
    do: put_block(state, index, :thinking, event["content"])

  defp update_thinking(state, _index, _action, _event), do: state

  defp update_tool_call(state, index, "start", event), do: put_preparing_tool(state, index, event)

  defp update_tool_call(state, index, "delta", event),
    do: append_tool_arguments(state, index, event["delta"])

  defp update_tool_call(state, index, "end", event),
    do: finish_preparing_tool(state, index, event["toolCall"])

  defp update_tool_call(state, _index, _action, _event), do: state

  defp put_block(state, index, type, content),
    do: put_in(state.partial.blocks[index], %{type: type, content: cap_text(content || "")})

  defp append_block(state, index, type, delta) do
    block = state.partial.blocks[index] || %{type: type, content: ""}
    content = cap_text(block.content <> cap_text(delta))
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
      put_in(state.tools[id], %{tool | args: cap_text(args <> cap_text(delta))})
    else
      _ -> state
    end
  end

  defp finish_preparing_tool(state, _index, %{"id" => id} = call) when is_binary(id) do
    case state.tools[id] do
      nil -> state
      tool -> put_tool(state, id, %{tool | name: call["name"], args: call["arguments"]})
    end
  end

  defp finish_preparing_tool(state, _index, _call), do: state

  defp update_tool(state, id, event, updates) do
    tool = state.tools[id] || %{id: id, name: event["toolName"], args: event["args"]}
    put_tool(state, id, Map.merge(tool, updates))
  end

  defp put_tool(state, id, tool) when is_binary(id) do
    order = if id in state.tool_order, do: state.tool_order, else: state.tool_order ++ [id]
    %{state | tools: Map.put(state.tools, id, cap_tool(tool)), tool_order: order}
  end

  defp put_tool(state, _id, _tool), do: state

  defp cap_tool(tool) do
    args =
      if is_binary(tool.args), do: tool.args, else: inspect(tool.args, pretty: true, limit: 100)

    name = if is_binary(tool.name), do: tool.name, else: "unknown"
    %{tool | name: name, args: cap_text(args)}
  end

  defp cap_result(%{"content" => content}) when is_list(content) do
    text =
      content
      |> Enum.flat_map(fn
        %{"type" => "text", "text" => text} when is_binary(text) -> [text]
        _block -> []
      end)
      |> Enum.join("\n")
      |> cap_text()

    %{"content" => [%{"type" => "text", "text" => text}]}
  end

  defp cap_result(_result), do: nil

  defp hydrate_tool(%{"role" => "assistant", "content" => content}, state)
       when is_list(content) do
    Enum.reduce(content, state, fn
      %{"type" => "toolCall", "id" => id} = call, result when is_binary(id) ->
        put_tool(result, id, %{
          id: id,
          name: call["name"],
          args: call["arguments"],
          result: nil,
          status: :done,
          error: false
        })

      _call, result ->
        result
    end)
  end

  defp hydrate_tool(%{"role" => "toolResult", "toolCallId" => id} = message, state)
       when is_binary(id) do
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
    do: [Map.put(message, "content", cap_text(content))]

  defp cap_message(%{"content" => content} = message) when is_list(content) do
    content =
      Enum.flat_map(content, fn
        %{"type" => "text", "text" => text} = block when is_binary(text) ->
          [Map.put(block, "text", cap_text(text))]

        %{"type" => "thinking", "thinking" => text} = block when is_binary(text) ->
          [Map.put(block, "thinking", cap_text(text))]

        %{"type" => "toolCall", "id" => id} = block when is_binary(id) ->
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

    [Map.put(message, "content", content)]
  end

  defp cap_message(message) when is_map(message), do: [message]
  defp cap_message(_message), do: []
  defp cap_text(text) when is_binary(text), do: String.byte_slice(text, 0, @max_text_bytes)
  defp cap_text(_text), do: ""
end
