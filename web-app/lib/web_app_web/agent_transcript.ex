defmodule WebAppWeb.AgentTranscript do
  use WebAppWeb, :html

  alias WebApp.AgentState

  attr :id, :string, required: true
  attr :item, :map, required: true
  attr :streaming, :boolean, default: false
  attr :expanded, :boolean, default: false

  def transcript_item(assigns) do
    ~H"""
    <article
      :if={@item.kind == :message}
      id={@id}
      class={[
        "text-sm leading-6 text-base-content/85",
        @item.role == :agent &&
          if(Map.get(@item, :after_activity?, false), do: "mt-4", else: "mt-8"),
        @item.role == :user && "mt-8 first:mt-0",
        @item.role == :user &&
          "ml-auto w-fit max-w-[92%] rounded-2xl border border-base-content/12 bg-base-200/35 px-3.5 py-2.5 text-left"
      ]}
    >
      <div :if={!@streaming} class="markdown">{markdown(@item.text)}</div>
      <div :if={@streaming} class="whitespace-pre-wrap">
        {@item.text}<span
          :if={@item.role == :agent}
          class="ml-1 inline-block h-4 w-0.5 animate-pulse bg-primary align-middle"
        ></span>
      </div>
    </article>

    <details
      :if={@item.kind == :work_turn}
      id={@id}
      data-work-id={String.replace_prefix(@id, "messages-", "")}
      phx-hook="WorkDisclosure"
      open={Map.get(@item, :expanded?, false)}
      class="group mt-8 w-full text-sm text-base-content/70"
    >
      <summary class="flex cursor-pointer list-none items-center gap-2 text-xs font-medium text-base-content/55 focus:outline-none focus-visible:ring-2 focus-visible:ring-primary">
        <.icon name="hero-chevron-down" class="size-3 transition-transform group-open:rotate-180" />
        <span>{work_label(@item)}</span>
      </summary>
      <div class="space-y-4 pt-3">
        <p :for={message <- @item.messages} class="whitespace-pre-wrap">{message.text}</p>
        <details
          :if={@item.traces != []}
          id={"#{@id}-activity"}
          class="group/activity text-xs text-base-content/60"
        >
          <summary class="flex cursor-pointer list-none items-center gap-2 focus:outline-none focus-visible:ring-2 focus-visible:ring-primary">
            <.icon name="hero-wrench-screwdriver" class="size-3.5" />
            <span>Activity ({length(@item.traces)})</span>
          </summary>
          <div class="mt-3 max-h-96 space-y-2 overflow-y-auto px-1">
            <.transcript_item
              :for={trace <- @item.traces}
              id={trace.id}
              item={trace}
              expanded={false}
            />
          </div>
        </details>
      </div>
    </details>

    <article
      :if={@item.kind == :notification}
      id={@id}
      class={[
        "mt-4 rounded-lg border px-4 py-3 text-sm text-base-content/75",
        @item.status == "sent" && "border-info/30 bg-info/10",
        @item.status == "failed" && "border-error/30 bg-error/10",
        @item.status not in ["sent", "failed"] && "border-primary/20 bg-primary/5"
      ]}
    >
      <p class={[
        "mb-1 text-xs font-semibold uppercase tracking-wide",
        @item.status == "sent" && "text-info",
        @item.status == "failed" && "text-error",
        @item.status not in ["sent", "failed"] && "text-primary"
      ]}>
        Activity · {@item.status}
      </p>
      <div class="markdown">{markdown(@item.content)}</div>
    </article>

    <details
      :if={@item.kind == :thinking}
      id={@id}
      open={@expanded}
      class="group w-full py-2 text-xs text-base-content/55"
    >
      <summary class="flex cursor-pointer list-none items-center gap-2 focus:outline-none focus-visible:ring-2 focus-visible:ring-primary">
        <span class="text-sm leading-none" role="img" aria-label="Thinking">🧠</span>
        <span>Thinking</span>
      </summary>
      <p class="mt-3 whitespace-pre-wrap">{@item.text}</p>
    </details>

    <details
      :if={@item.kind == :tool}
      id={@id}
      open={@expanded}
      class="group w-full py-2 text-xs text-base-content/55"
    >
      <summary class={[
        "flex cursor-pointer list-none items-center gap-2 focus:outline-none focus-visible:ring-2 focus-visible:ring-primary",
        @item.tool.error && "text-error"
      ]}>
        <.icon name="hero-command-line" class="size-3.5" />
        <span class="font-mono font-medium">{@item.tool.name}</span>
      </summary>
      <pre class="mt-3 max-h-72 overflow-auto rounded-lg bg-base-200 p-3 font-mono text-[0.7rem] leading-5 text-base-content/65">{tool_output(@item.tool)}</pre>
    </details>
    """
  end

  def work_label(%{active?: true}), do: "Working"

  def work_label(%{duration: duration}) when is_integer(duration),
    do: "Worked for #{format_duration(duration)}"

  def work_label(_item), do: "Worked"

  defp format_duration(duration) when duration < 60_000, do: "#{max(div(duration, 1_000), 1)}s"

  defp format_duration(duration),
    do: "#{div(duration, 60_000)}m #{rem(div(duration, 1_000), 60)}s"

  def markdown(text), do: {:safe, MDEx.to_html!(text)}
  def command_location(command), do: get_in(command, ["sourceInfo", "scope"]) || "unknown"
  def command_path(command), do: get_in(command, ["sourceInfo", "path"]) || ""

  def message_text(%{"content" => content}) when is_binary(content), do: content

  def message_text(%{"content" => content}) when is_list(content) do
    content
    |> Enum.filter(&(&1["type"] == "text"))
    |> Enum.map_join("\n", & &1["text"])
  end

  def message_text(%{"summary" => summary}), do: summary
  def message_text(_message), do: ""

  def display_message_text(message) do
    case Regex.run(~r/^<skill name="([^"]+)"[^>]*>.*<\/skill>(.*)$/s, message_text(message)) do
      [_, name, arguments] ->
        command = "/skill:#{name}"
        arguments = String.trim(arguments)
        if arguments == "", do: command, else: command <> "\n\n" <> arguments

      nil ->
        message_text(message)
    end
  end

  def visible_message?(%{"role" => role}),
    do: role in ["user", "assistant", "custom", "branchSummary", "compactionSummary"]

  def visible_message?(_message), do: false

  def partial_text(session), do: AgentState.partial_text(session)
  def partial_thinking(session), do: AgentState.partial_thinking(session)

  def partial_items(session) do
    session.partial.blocks
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.flat_map(fn {index, block} ->
      case block do
        %{type: :text, content: text} when text != "" ->
          [%{id: "partial-#{index}", kind: :message, role: :agent, text: text}]

        %{type: :thinking, content: text} when text != "" ->
          [%{id: "partial-#{index}", kind: :thinking, text: text}]

        %{type: :tool_call, content: id} ->
          tool_item("partial-#{index}", session.tools[id])

        _ ->
          []
      end
    end)
  end

  def tool_status(tool) do
    cond do
      tool.status == :preparing -> "Preparing"
      tool.status == :running -> "Running"
      tool.error -> "Failed"
      true -> "Complete"
    end
  end

  def tool_output(%{args: args, result: nil}), do: args
  def tool_output(%{args: args, result: result}), do: args <> "\n\n" <> tool_result(result)
  def tool_result(nil), do: ""

  def tool_result(result) do
    result
    |> Map.get("content", [])
    |> Enum.filter(&(&1["type"] == "text"))
    |> Enum.map_join("\n", & &1["text"])
    |> String.slice(0, 12_000)
  end

  def mark_expanded_work(items, expanded_work_ids) do
    Enum.map(items, fn item ->
      if item.kind == :work_turn,
        do: Map.put(item, :expanded?, MapSet.member?(expanded_work_ids, item.id)),
        else: item
    end)
  end

  def notification_items(messages) do
    Enum.map(messages, fn message ->
      %{
        id: "notification-#{message.id}",
        kind: :notification,
        content: message.content,
        status: message.sent_status,
        timestamp: message.timestamp
      }
    end)
  end

  def timeline_items(transcript, notifications) do
    Enum.sort_by(transcript ++ notifications, &timeline_sort_key/1)
  end

  defp timeline_sort_key(%{timestamp: %DateTime{} = timestamp}),
    do: {0, DateTime.to_unix(timestamp, :millisecond)}

  defp timeline_sort_key(%{timestamp: timestamp}) when is_integer(timestamp), do: {0, timestamp}

  defp timeline_sort_key(%{timestamp: timestamp}) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _offset} -> {0, DateTime.to_unix(datetime, :millisecond)}
      _ -> {1, 0}
    end
  end

  defp timeline_sort_key(_item), do: {1, 0}

  def transcript_items(session) do
    session
    |> message_items_for_session()
    |> work_turn_items(
      partial_items(session),
      agent_active?(session.status),
      session.last_run_duration
    )
  end

  defp message_items_for_session(session) do
    session.messages
    |> Enum.with_index()
    |> Enum.flat_map(fn {message, message_index} ->
      message_items(message, message_index, session)
    end)
  end

  def work_turn_items(items, partial, active?), do: work_turn_items(items, partial, active?, nil)

  def work_turn_items(items, partial, active?, duration) do
    {result, current} =
      Enum.reduce(items, {[], []}, fn item, {result, current} ->
        if item.kind == :message && item.role == :user do
          {result ++ finish_work_turn(current, false), [item]}
        else
          {result, current ++ [item]}
        end
      end)

    result
    |> Kernel.++(finish_work_turn(current ++ partial, active?))
    |> put_work_duration(duration)
  end

  defp put_work_duration(items, nil), do: items

  defp put_work_duration(items, duration) do
    case Enum.find_index(Enum.reverse(items), &(&1.kind == :work_turn)) do
      nil ->
        items

      reverse_index ->
        List.update_at(
          items,
          length(items) - reverse_index - 1,
          &Map.put(&1, :duration, duration)
        )
    end
  end

  defp finish_work_turn([], _active?), do: []

  defp finish_work_turn([%{kind: :message, role: :user} = user | items], active?) do
    {final, work} = split_final_message(items, active?)
    work_item = work_turn_item(user, work, active?)
    [user] ++ List.wrap(work_item) ++ List.wrap(final)
  end

  defp finish_work_turn(items, _active?), do: items

  defp split_final_message(items, true), do: {nil, items}

  defp split_final_message(items, false) do
    case Enum.find_index(Enum.reverse(items), &agent_message?/1) do
      nil ->
        {nil, items}

      reverse_index ->
        index = length(items) - reverse_index - 1
        {Enum.at(items, index), List.delete_at(items, index)}
    end
  end

  defp work_turn_item(_user, [], _active?), do: nil

  defp work_turn_item(user, items, active?) do
    traces = Enum.filter(items, &(&1.kind in [:thinking, :tool]))
    messages = Enum.filter(items, &agent_message?/1)

    %{
      id: "work-#{user.id}-#{if active?, do: "active", else: "settled"}",
      kind: :work_turn,
      timestamp: Map.get(user, :timestamp),
      active?: active?,
      duration: nil,
      messages: messages,
      traces: Enum.reverse(traces)
    }
  end

  defp agent_message?(%{kind: :message, role: :agent}), do: true
  defp agent_message?(_item), do: false

  defp agent_active?(status), do: status in [:working, :retrying, :compacting, :waiting_for_input]

  defp tool_item(_id, nil), do: []
  defp tool_item(id, tool), do: [%{id: id, kind: :tool, tool: tool}]

  defp message_items(
         %{"role" => "assistant", "content" => content} = message,
         message_index,
         session
       )
       when is_list(content) do
    content
    |> Enum.with_index()
    |> Enum.flat_map(fn {block, block_index} ->
      id = "message-#{message_index}-#{block_index}"

      case block do
        %{"type" => "text", "text" => text} when text != "" ->
          [%{id: id, kind: :message, role: :agent, text: text, timestamp: message["timestamp"]}]

        %{"type" => "thinking", "thinking" => text} when text != "" ->
          [%{id: id, kind: :thinking, text: text}]

        %{"type" => "toolCall", "id" => tool_id} ->
          tool_item(id, session.tools[tool_id])

        _ ->
          []
      end
    end)
  end

  defp message_items(%{"role" => role} = message, message_index, _session)
       when role in ["user", "custom", "branchSummary", "compactionSummary"] do
    text = display_message_text(message)
    role = if role == "user", do: :user, else: :agent

    if text == "",
      do: [],
      else: [
        %{
          id: "message-#{message_index}",
          kind: :message,
          role: role,
          text: text,
          timestamp: message["timestamp"]
        }
      ]
  end

  defp message_items(_message, _message_index, _session), do: []
end
