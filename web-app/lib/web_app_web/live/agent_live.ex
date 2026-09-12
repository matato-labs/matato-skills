defmodule WebAppWeb.AgentLive do
  use WebAppWeb, :live_view

  alias WebApp.{
    AgentFanout,
    AgentSession,
    AgentState,
    ProjectSessionCatalog,
    RemoteRegistry
  }

  alias WebAppWeb.SessionComponents

  @max_prompt_bytes 100_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: RemoteRegistry.subscribe()
    sessions = RemoteRegistry.list()

    socket =
      assign(socket,
        page_title: "Matato Agent",
        sessions: sessions,
        workspace_groups: ProjectSessionCatalog.workspace_groups(sessions),
        automation_groups: ProjectSessionCatalog.automation_groups(sessions),
        session_id: nil,
        delete_session_id: nil,
        mobile_sidebar_open: false,
        session: nil,
        draft: "",
        interaction_owner: false,
        error: nil,
        composer_form: to_form(%{"message" => ""}, as: :composer),
        dialog_form: to_form(%{"value" => ""}, as: :dialog)
      )

    {:ok, stream(socket, :messages, [])}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    if connected?(socket), do: AgentFanout.subscribe(id)

    case RemoteRegistry.open(id) do
      :ok ->
        owner = if connected?(socket), do: AgentSession.claim(id, self()) == :owner, else: false

        snapshot = AgentSession.snapshot(id)

        {:noreply,
         socket
         |> assign(
           session_id: id,
           interaction_owner: owner,
           mobile_sidebar_open: false,
           error: nil
         )
         |> sync_session(snapshot)}

      {:error, error} ->
        {:noreply,
         assign(socket, session_id: id, session: nil, mobile_sidebar_open: false, error: error)}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event(event, _params, %{assigns: %{interaction_owner: false}} = socket)
      when event in ["compose", "abort", "clear_queue", "stop", "dialog"] do
    {:noreply, assign(socket, error: "Take interaction control before changing this session")}
  end

  def handle_event("confirm_delete_session", %{"id" => id}, socket),
    do: {:noreply, assign(socket, delete_session_id: id)}

  def handle_event("toggle_mobile_sidebar", _params, socket),
    do: {:noreply, update(socket, :mobile_sidebar_open, &(!&1))}

  def handle_event("close_mobile_sidebar", _params, socket),
    do: {:noreply, assign(socket, mobile_sidebar_open: false)}

  def handle_event("delete_session", %{"id" => id}, socket) do
    case RemoteRegistry.delete(id) do
      :ok when id == socket.assigns.session_id ->
        {:noreply, push_navigate(socket, to: "/")}

      :ok ->
        {:noreply, socket |> assign_sessions() |> assign(delete_session_id: nil)}

      {:error, error} ->
        {:noreply, assign(socket, error: error, delete_session_id: nil)}
    end
  end

  def handle_event(
        "compose",
        %{"composer" => %{"message" => message}, "behavior" => behavior},
        socket
      ) do
    type = %{"send" => "prompt", "steer" => "steer", "later" => "follow_up"}[behavior] || "prompt"
    send_command(socket, type, message)
  end

  def handle_event("draft", %{"composer" => %{"message" => message}}, socket),
    do: {:noreply, set_draft(socket, message)}

  def handle_event("abort", _params, socket), do: run_command(socket, %{"type" => "abort"})

  def handle_event("clear_queue", _params, socket) do
    case command(socket, %{"type" => "clear_queue"}) do
      {:ok, data} ->
        restored = (data["steering"] || []) ++ (data["followUp"] || [])
        draft = Enum.join(restored, "\n\n")
        {:noreply, socket |> set_draft(draft) |> assign(error: nil)}

      {:error, error} ->
        {:noreply, assign(socket, error: error)}
    end
  end

  def handle_event("stop", _params, socket) do
    :ok = RemoteRegistry.stop(socket.assigns.session_id)

    {:noreply,
     assign(socket,
       session: %{socket.assigns.session | status: :stopped},
       interaction_owner: false
     )}
  end

  def handle_event("resume", _params, socket) do
    id = socket.assigns.session_id

    with :ok <- RemoteRegistry.open(id),
         :owner <- AgentSession.claim(id, self(), true) do
      {:noreply,
       socket
       |> assign(interaction_owner: true, error: nil)
       |> sync_session(AgentSession.snapshot(id))}
    else
      {:error, error} -> {:noreply, assign(socket, error: error)}
    end
  catch
    :exit, _reason -> {:noreply, assign(socket, error: "Agent process could not be resumed")}
  end

  def handle_event("takeover", _params, socket) do
    case AgentSession.claim(socket.assigns.session_id, self(), true) do
      :owner -> {:noreply, assign(socket, interaction_owner: true, error: nil)}
      :observer -> {:noreply, assign(socket, error: "Interaction control is unavailable")}
    end
  catch
    :exit, _reason ->
      {:noreply, assign(socket, error: "Resume the session before taking control")}
  end

  def handle_event("dialog", params, socket) do
    if socket.assigns.interaction_owner do
      response = dialog_response(socket.assigns.session.dialog, params)

      case AgentSession.respond(socket.assigns.session_id, self(), response) do
        :ok ->
          {:noreply, assign(socket, session: AgentState.clear_dialog(socket.assigns.session))}

        {:error, error} ->
          {:noreply, assign(socket, error: error)}
      end
    else
      {:noreply, assign(socket, error: "Take interaction control before answering")}
    end
  end

  @impl true
  def handle_info(:changed, socket), do: {:noreply, assign_sessions(socket)}

  def handle_info({:agent_snapshot, snapshot}, socket) do
    dialog_form =
      to_form(%{"value" => get_in(snapshot, [:dialog, "prefill"]) || ""}, as: :dialog)

    {:noreply,
     socket
     |> assign_sessions()
     |> assign(dialog_form: dialog_form, error: nil)
     |> sync_session(snapshot)}
  end

  def handle_info({:agent_owner, owner}, socket),
    do: {:noreply, assign(socket, interaction_owner: owner == self())}

  def handle_info(
        {:agent_hint, %{"method" => "set_editor_text", "text" => text}},
        %{assigns: %{interaction_owner: true}} = socket
      ),
      do: {:noreply, set_draft(socket, text)}

  def handle_info({:agent_hint, %{"method" => "set_editor_text"}}, socket),
    do: {:noreply, socket}

  def handle_info({:agent_hint, %{"method" => "setTitle", "title" => title}}, socket),
    do: {:noreply, assign(socket, page_title: title)}

  def handle_info({:agent_hint, _hint}, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, %{assigns: %{session_id: id}}) when is_binary(id) do
    if AgentSession.whereis(id), do: AgentSession.release(id, self())
    :ok
  end

  def terminate(_reason, _socket), do: :ok

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
      class="group mt-8 w-full text-sm text-base-content/70"
    >
      <summary class="flex cursor-pointer list-none items-center gap-2 border-b border-base-content/10 pb-2 text-xs font-medium text-base-content/55 focus:outline-none focus-visible:ring-2 focus-visible:ring-primary">
        <.icon name="hero-chevron-down" class="size-3 transition-transform group-open:rotate-180" />
        <span>{work_label(@item)}</span>
      </summary>
      <div class="space-y-4 pt-4">
        <p :for={message <- @item.messages} class="whitespace-pre-wrap">{message.text}</p>
        <details :if={@item.traces != []} class="group/activity text-xs text-base-content/60">
          <summary class="flex cursor-pointer list-none items-center gap-2 focus:outline-none focus-visible:ring-2 focus-visible:ring-primary">
            <.icon name="hero-wrench-screwdriver" class="size-3.5" />
            <span>Activity ({length(@item.traces)})</span>
          </summary>
          <div class="mt-3 max-h-96 space-y-2 overflow-y-auto rounded-lg bg-base-content/5 p-3">
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

  defp send_command(socket, _type, message) when message in [nil, ""], do: {:noreply, socket}

  defp send_command(socket, type, message) do
    message = String.trim(message)

    cond do
      message == "" ->
        {:noreply, socket}

      byte_size(message) > @max_prompt_bytes ->
        {:noreply, assign(socket, error: "Prompt exceeds 100 KB")}

      true ->
        case command(socket, %{"type" => type, "message" => message}) do
          :ok -> {:noreply, socket |> set_draft("") |> assign(error: nil)}
          {:error, error} -> {:noreply, assign(socket, error: error)}
        end
    end
  end

  defp run_command(socket, command) do
    case command(socket, command) do
      :ok -> {:noreply, assign(socket, error: nil)}
      {:ok, _data} -> {:noreply, assign(socket, error: nil)}
      {:error, error} -> {:noreply, assign(socket, error: error)}
    end
  end

  defp command(socket, command) do
    AgentSession.owner_command(socket.assigns.session_id, self(), command)
  catch
    :exit, _reason -> {:error, "Agent process is unavailable. Resume the session to reconnect."}
  end

  defp set_draft(socket, draft) do
    assign(socket, draft: draft, composer_form: to_form(%{"message" => draft}, as: :composer))
  end

  defp assign_sessions(socket) do
    sessions = RemoteRegistry.list()

    assign(socket,
      sessions: sessions,
      workspace_groups: ProjectSessionCatalog.workspace_groups(sessions),
      automation_groups: ProjectSessionCatalog.automation_groups(sessions)
    )
  end

  defp sync_session(socket, snapshot) do
    socket
    |> assign(session: snapshot)
    |> stream(
      :messages,
      transcript_items(snapshot),
      reset: true
    )
  end

  defp transcript_items(session) do
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
      active?: active?,
      duration: nil,
      messages: messages,
      traces: Enum.reverse(traces)
    }
  end

  defp agent_message?(%{kind: :message, role: :agent}), do: true
  defp agent_message?(_item), do: false

  defp agent_active?(status), do: status in [:working, :retrying, :compacting, :waiting_for_input]

  defp message_items(%{"role" => "assistant", "content" => content}, message_index, session)
       when is_list(content) do
    content
    |> Enum.with_index()
    |> Enum.flat_map(fn {block, block_index} ->
      id = "message-#{message_index}-#{block_index}"

      case block do
        %{"type" => "text", "text" => text} when text != "" ->
          [%{id: id, kind: :message, role: :agent, text: text}]

        %{"type" => "thinking", "thinking" => text} when text != "" ->
          [%{id: id, kind: :thinking, text: text}]

        %{"type" => "toolCall", "id" => tool_id} ->
          [%{id: id, kind: :tool, tool: session.tools[tool_id]}]

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
      else: [%{id: "message-#{message_index}", kind: :message, role: role, text: text}]
  end

  defp message_items(_message, _message_index, _session), do: []

  defp dialog_response(%{"id" => id, "method" => "confirm"}, params) do
    %{"type" => "extension_ui_response", "id" => id, "confirmed" => params["answer"] == "true"}
  end

  defp dialog_response(%{"id" => id}, %{"cancel" => "true"}),
    do: %{"type" => "extension_ui_response", "id" => id, "cancelled" => true}

  defp dialog_response(%{"id" => id}, %{"dialog" => params}),
    do: %{"type" => "extension_ui_response", "id" => id, "value" => params["value"]}

  defp dialog_response(%{"id" => id}, params),
    do: %{"type" => "extension_ui_response", "id" => id, "value" => params["value"]}
end
