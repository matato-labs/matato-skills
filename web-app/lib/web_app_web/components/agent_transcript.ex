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
          [%{id: "partial-#{index}", kind: :tool, tool: session.tools[id]}]

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

  defp format_duration(duration) when duration < 60_000, do: "#{max(div(duration, 1_000), 1)}s"

  defp format_duration(duration),
    do: "#{div(duration, 60_000)}m #{rem(div(duration, 1_000), 60)}s"
end
