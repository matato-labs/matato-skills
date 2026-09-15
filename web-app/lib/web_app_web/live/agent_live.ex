defmodule WebAppWeb.AgentLive do
  use WebAppWeb, :live_view

  alias WebApp.{
    AgentFanout,
    AgentSession,
    AgentState,
    Bots,
    Messages,
    ProjectSessionCatalog,
    RemoteRegistry,
    RemoteSessions
  }

  alias WebAppWeb.SessionComponents

  @max_prompt_bytes 100_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      RemoteRegistry.subscribe()
      Bots.subscribe()
    end

    sessions = RemoteRegistry.list()

    socket =
      assign(socket,
        page_title: "Matato Agent",
        sessions: sessions,
        workspace_groups: ProjectSessionCatalog.workspace_groups(sessions),
        automation_groups: ProjectSessionCatalog.automation_groups(sessions),
        bots: Bots.list(),
        session_id: nil,
        bot: nil,
        chat_name: nil,
        show_bot_form: false,
        bot_error: nil,
        bot_form: bot_form(),
        show_bot_editor: false,
        bot_editor_error: nil,
        bot_editor_form: bot_form(),
        delete_session_id: nil,
        delete_bot_id: nil,
        mobile_sidebar_open: false,
        session: nil,
        draft: "",
        error: nil,
        composer_form: to_form(%{"message" => ""}, as: :composer),
        dialog_form: to_form(%{"value" => ""}, as: :dialog),
        expanded_work_ids: MapSet.new()
      )

    {:ok, stream(socket, :messages, [])}
  end

  @impl true
  def handle_params(%{"bot_id" => bot_id}, _uri, socket) do
    case Bots.get(bot_id) do
      nil ->
        {:noreply, assign(socket, bot: nil, chat_name: nil, session: nil, error: "Bot not found")}

      bot ->
        if connected?(socket), do: Messages.subscribe(bot.id)
        open_bot_chat(socket, bot)
    end
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    if connected?(socket), do: AgentFanout.subscribe(id)

    case RemoteRegistry.open(id) do
      :ok ->
        snapshot = AgentSession.snapshot(id)

        {:noreply,
         socket
         |> assign(
           session_id: id,
           bot: nil,
           chat_name: session_name(id),
           mobile_sidebar_open: false,
           expanded_work_ids: MapSet.new(),
           error: nil
         )
         |> sync_session(snapshot)}

      {:error, error} ->
        {:noreply,
         assign(socket,
           session_id: id,
           bot: nil,
           chat_name: nil,
           session: nil,
           mobile_sidebar_open: false,
           error: error
         )}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("show_bot_form", _params, socket),
    do: {:noreply, assign(socket, show_bot_form: true, bot_error: nil, bot_form: bot_form())}

  def handle_event("hide_bot_form", _params, socket),
    do: {:noreply, assign(socket, show_bot_form: false, bot_error: nil)}

  def handle_event("create_bot", %{"bot" => params}, socket) do
    case Bots.create(params) do
      {:ok, bot} -> {:noreply, push_navigate(socket, to: "/bots/#{bot.id}")}
      {:error, reason} -> {:noreply, assign(socket, bot_error: format_error(reason))}
    end
  end

  def handle_event("show_bot_editor", _params, %{assigns: %{bot: nil}} = socket),
    do: {:noreply, socket}

  def handle_event("show_bot_editor", _params, socket) do
    {:noreply,
     assign(socket,
       show_bot_editor: true,
       bot_editor_error: nil,
       bot_editor_form: bot_form(socket.assigns.bot)
     )}
  end

  def handle_event("hide_bot_editor", _params, socket),
    do: {:noreply, assign(socket, show_bot_editor: false, bot_editor_error: nil)}

  def handle_event("update_bot", %{"bot" => params}, %{assigns: %{bot: bot}} = socket) do
    case Bots.update(bot.id, params) do
      {:ok, bot} ->
        {:noreply,
         socket
         |> assign(bot: bot, chat_name: bot.name, show_bot_editor: false, bot_editor_error: nil)
         |> assign_sessions()}

      {:error, reason} ->
        {:noreply,
         assign(socket, bot_editor_error: format_error(reason), bot_editor_form: bot_form(params))}
    end
  end

  def handle_event("confirm_delete_session", %{"id" => id}, socket),
    do: {:noreply, assign(socket, delete_session_id: id)}

  def handle_event("confirm_delete_bot", %{"id" => id}, socket),
    do: {:noreply, assign(socket, delete_bot_id: id)}

  def handle_event("delete_bot", %{"id" => id}, socket) do
    case Bots.delete(id) do
      :ok ->
        {:noreply, push_navigate(socket, to: "/")}

      {:error, :not_found} ->
        {:noreply, assign(socket, error: "Bot not found", delete_bot_id: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, error: format_error(reason), delete_bot_id: nil)}
    end
  end

  def handle_event("toggle_work", %{"id" => id, "open" => "true"}, socket),
    do: {:noreply, update(socket, :expanded_work_ids, &MapSet.put(&1, id))}

  def handle_event("toggle_work", %{"id" => id, "open" => "false"}, socket),
    do: {:noreply, update(socket, :expanded_work_ids, &MapSet.delete(&1, id))}

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
        %{"composer" => %{"message" => message}, "behavior" => "steer"},
        socket
      ),
      do: send_command(socket, "steer", message)

  def handle_event("compose", %{"composer" => %{"message" => message}}, socket),
    do:
      send_command(
        socket,
        if(agent_active?(socket.assigns.session.status), do: "follow_up", else: "prompt"),
        message
      )

  def handle_event("draft", %{"composer" => %{"message" => message}}, socket),
    do: {:noreply, set_draft(socket, message)}

  def handle_event("abort", _params, socket), do: run_command(socket, %{"type" => "abort"})

  def handle_event("stop", _params, socket) do
    :ok = RemoteRegistry.stop(socket.assigns.session_id)

    {:noreply, assign(socket, session: %{socket.assigns.session | status: :stopped})}
  end

  def handle_event("resume", _params, socket) do
    id = socket.assigns.session_id

    case RemoteRegistry.open(id) do
      :ok -> {:noreply, socket |> assign(error: nil) |> sync_session(AgentSession.snapshot(id))}
      {:error, error} -> {:noreply, assign(socket, error: error)}
    end
  catch
    :exit, _reason -> {:noreply, assign(socket, error: "Agent process could not be resumed")}
  end

  def handle_event("dialog", params, socket) do
    response = dialog_response(socket.assigns.session.dialog, params)

    case AgentSession.respond(socket.assigns.session_id, response) do
      :ok -> {:noreply, assign(socket, session: AgentState.clear_dialog(socket.assigns.session))}
      {:error, error} -> {:noreply, assign(socket, error: error)}
    end
  end

  @impl true
  def handle_info(:changed, socket), do: {:noreply, assign_sessions(socket)}

  def handle_info({:message_changed, _bot_id}, %{assigns: %{session: session, bot: bot}} = socket)
      when not is_nil(session) and not is_nil(bot),
      do: {:noreply, sync_session(socket, session)}

  def handle_info({:agent_snapshot, snapshot}, socket) do
    dialog_form =
      to_form(%{"value" => get_in(snapshot, [:dialog, "prefill"]) || ""}, as: :dialog)

    {:noreply,
     socket
     |> assign_sessions()
     |> assign(dialog_form: dialog_form, error: nil)
     |> sync_session(snapshot)}
  end

  def handle_info({:agent_hint, %{"method" => "set_editor_text", "text" => text}}, socket),
    do: {:noreply, set_draft(socket, text)}

  def handle_info({:agent_hint, %{"method" => "setTitle", "title" => title}}, socket),
    do: {:noreply, assign(socket, page_title: title)}

  def handle_info({:agent_hint, _hint}, socket), do: {:noreply, socket}

  defdelegate transcript_item(assigns), to: WebAppWeb.AgentTranscript

  defdelegate work_label(item), to: WebAppWeb.AgentTranscript
  defdelegate markdown(text), to: WebAppWeb.AgentTranscript
  defdelegate command_location(command), to: WebAppWeb.AgentTranscript
  defdelegate command_path(command), to: WebAppWeb.AgentTranscript
  defdelegate message_text(message), to: WebAppWeb.AgentTranscript
  defdelegate display_message_text(message), to: WebAppWeb.AgentTranscript
  defdelegate visible_message?(message), to: WebAppWeb.AgentTranscript
  defdelegate partial_text(session), to: WebAppWeb.AgentTranscript
  defdelegate partial_thinking(session), to: WebAppWeb.AgentTranscript
  defdelegate partial_items(session), to: WebAppWeb.AgentTranscript
  defdelegate tool_status(tool), to: WebAppWeb.AgentTranscript
  defdelegate tool_output(tool), to: WebAppWeb.AgentTranscript
  defdelegate tool_result(result), to: WebAppWeb.AgentTranscript

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
    AgentSession.command(socket.assigns.session_id, command)
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
      automation_groups: ProjectSessionCatalog.automation_groups(sessions),
      bots: Bots.list()
    )
  end

  defp bot_form, do: bot_form(%{})

  defp bot_form(bot) do
    to_form(
      %{
        "name" => Map.get(bot, :name) || Map.get(bot, "name", ""),
        "role" => Map.get(bot, :role) || Map.get(bot, "role", ""),
        "description" => Map.get(bot, :description) || Map.get(bot, "description", "")
      },
      as: :bot
    )
  end

  defp session_name(id) do
    case RemoteSessions.get(id) do
      %{"name" => name} -> name
      nil -> nil
    end
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp sync_session(socket, snapshot) do
    internal_messages =
      if socket.assigns.bot, do: Messages.list_for_bot(socket.assigns.bot.id), else: []

    socket
    |> assign(session: snapshot)
    |> stream(
      :messages,
      timeline_items(transcript_items(snapshot), notification_items(internal_messages))
      |> mark_expanded_work(socket.assigns.expanded_work_ids),
      reset: true
    )
  end

  defp open_bot_chat(socket, bot) do
    id = bot.chat_remote_session_id
    if connected?(socket), do: AgentFanout.subscribe(id)

    case RemoteRegistry.open(id, Bots.identity_for(bot)) do
      :ok ->
        {:noreply,
         socket
         |> assign(
           bot: bot,
           chat_name: bot.name,
           session_id: id,
           mobile_sidebar_open: false,
           expanded_work_ids: MapSet.new(),
           error: nil
         )
         |> sync_session(AgentSession.snapshot(id))}

      {:error, error} ->
        {:noreply,
         assign(socket,
           bot: bot,
           chat_name: bot.name,
           session_id: id,
           session: nil,
           mobile_sidebar_open: false,
           error: error
         )}
    end
  end

  defp mark_expanded_work(items, expanded_work_ids) do
    Enum.map(items, fn item ->
      if item.kind == :work_turn,
        do: Map.put(item, :expanded?, MapSet.member?(expanded_work_ids, item.id)),
        else: item
    end)
  end

  defp notification_items(messages) do
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

  defp timeline_items(transcript, notifications) do
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
