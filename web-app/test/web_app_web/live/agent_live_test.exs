defmodule WebAppWeb.AgentLiveTest do
  use WebAppWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias WebApp.{AgentFanout, AgentSession, Messages, RemoteSessions, Repo, Workspace}
  alias WebApp.Bots.Bot
  alias WebApp.Messages.Message

  setup do
    root = Path.join(System.tmp_dir!(), "agent-live-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    executable = Path.join(root, "fakepi")

    File.write!(executable, """
    #!/usr/bin/env python3
    import json, sys
    model = {"provider": "anthropic", "id": "claude-sonnet", "name": "Claude Sonnet"}
    for line in sys.stdin:
      command = json.loads(line)
      with open("#{root}/commands.jsonl", "a") as file:
        file.write(json.dumps(command) + "\\n")
      response = {"id": command["id"], "type": "response", "command": command["type"], "success": True}
      if command["type"] == "get_state":
        response["data"] = {"model": model, "thinkingLevel": "medium", "isStreaming": False, "isCompacting": False, "sessionFile": None, "sessionId": "pi-1"}
      elif command["type"] == "get_available_models":
        response["data"] = {"models": [{"provider": "anthropic", "id": "claude-sonnet", "name": "Claude Sonnet"}, {"provider": "openai", "id": "gpt-5.6", "name": "GPT-5.6"}]}
      elif command["type"] == "get_available_thinking_levels":
        response["data"] = {"levels": ["low", "high"] if model["id"] == "gpt-5.6" else ["off", "low", "medium", "high"]}
      elif command["type"] == "set_model":
        model = {"provider": command["provider"], "id": command["modelId"], "name": command["modelId"]}
        response["data"] = model
      elif command["type"] == "get_messages":
        response["data"] = {"messages": [{"role": "user", "content": "First prompt", "timestamp": 1000}, {"role": "assistant", "content": [{"type": "text", "text": "First reply"}], "timestamp": 3000}]}
      elif command["type"] == "get_commands":
        response["data"] = {"commands": [{"name": "plan", "description": "Plan the work", "source": "prompt", "sourceInfo": {"path": "#{root}/.pi/prompts/plan.md", "scope": "project"}}]}
      if command["type"] == "trigger_active":
        print(json.dumps({"type": "agent_start"}), flush=True)
      elif command["type"] == "queue_follow_up":
        print(json.dumps({"type": "queue_update", "followUp": ["Run the tests"]}), flush=True)
      elif command["type"] == "queue_steering":
        print(json.dumps({"type": "queue_update", "steering": ["Work on the design"]}), flush=True)
      elif command["type"] == "abort":
        print(json.dumps({"type": "queue_update", "steering": [], "followUp": []}), flush=True)
      elif command["type"] == "clear_follow_up":
        print(json.dumps({"type": "queue_update", "followUp": []}), flush=True)
      print(json.dumps(response), flush=True)
    """)

    File.chmod!(executable, 0o700)
    id = Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)
    project = Path.join(Workspace.root(), "agent-live-#{id}")
    File.mkdir_p!(project)
    AgentFanout.subscribe(id)

    start_supervised!(
      {AgentSession,
       id: id, name: "test", project: project, executable: executable, interrupted: false},
      id: id
    )

    assert :ok = AgentSession.await_ready(id)
    assert_receive {:agent_update, ^id, _sequence, {:commands_ready, [_command]}}, 2_000

    {:ok, _session} =
      RemoteSessions.create(%{
        id: id,
        name: "test",
        project_path: project,
        relative_project: Path.relative_to(project, Workspace.root()),
        source: "web",
        status: "settled"
      })

    bot =
      Repo.insert!(%Bot{
        name: "Test bot",
        role: "tester",
        description: "Tests UI",
        chat_remote_session_id: id,
        background_remote_session_id: "background-#{id}"
      })

    on_exit(fn ->
      Repo.delete_all(Message)
      Repo.delete(bot)
      :ok = RemoteSessions.delete(id)

      File.rm_rf!(root)
      File.rm_rf!(project)
    end)

    %{id: id, bot: bot, root: root}
  end

  test "renders persisted bot activity in the bot chat", %{conn: conn, bot: bot} do
    {:ok, _message} =
      Messages.create(%{
        receiver_bot_id: bot.id,
        sender_type: "automation",
        timestamp: DateTime.from_unix!(2, :second),
        kind: "result",
        content: "Daily review complete",
        sent_status: "sent"
      })

    {:ok, view, _html} = live(conn, "/bots/#{bot.id}")

    html = render(view)
    assert has_element?(view, "[id*='notification-']")
    assert html =~ "border-info/30"
    assert html =~ "text-info"
    assert html =~ "Daily review complete"
    assert {prompt_index, _length} = :binary.match(html, "First prompt")
    assert {activity_index, _length} = :binary.match(html, "Daily review complete")
    assert {reply_index, _length} = :binary.match(html, "First reply")
    assert prompt_index < activity_index
    assert activity_index < reply_index
  end

  test "keeps the chat header fixed on mobile", %{conn: conn, bot: bot} do
    {:ok, view, _html} = live(conn, "/bots/#{bot.id}")

    html = render(view)
    assert html =~ "fixed inset-x-0 top-0 z-10"
    assert html =~ "bg-base-300 pt-16 lg:pt-0"
  end

  test "shows the bot name and edits its identity from the chat header", %{conn: conn, bot: bot} do
    {:ok, view, _html} = live(conn, "/bots/#{bot.id}")

    assert has_element?(view, "#chat-header")
    assert has_element?(view, "#edit-bot-button")

    view |> element("#edit-bot-button") |> render_click()

    assert has_element?(view, "#bot-editor")
    assert has_element?(view, "#edit-bot-form")

    view
    |> form("#edit-bot-form",
      bot: %{name: "Edited bot", role: "editor", description: "Edits work"}
    )
    |> render_submit()

    refute has_element?(view, "#bot-editor")
    assert has_element?(view, "#chat-header", "Edited bot")
  end

  test "renders failed bot activity in red" do
    html =
      render_component(&WebAppWeb.AgentLive.transcript_item/1,
        id: "notification-failed",
        item: %{kind: :notification, status: "failed", content: "Delivery failed"}
      )

    assert html =~ "border-error/30"
    assert html =~ "bg-error/10"
    assert html =~ "text-error"
  end

  test "hides expanded skill content in the transcript" do
    message = %{
      "content" =>
        "<skill name=\"review\" location=\"/skills/review/SKILL.md\">\nReview instructions\n</skill>\n\nCheck the API"
    }

    assert WebAppWeb.AgentLive.display_message_text(message) == "/skill:review\n\nCheck the API"
  end

  test "omits tool activity missing from incomplete persisted and live transcript data" do
    session = %{
      WebApp.AgentState.new()
      | messages: [
          %{
            "role" => "assistant",
            "content" => [%{"type" => "toolCall", "id" => "missing"}]
          }
        ],
        partial: %{blocks: %{0 => %{type: :tool_call, content: "missing"}}}
    }

    assert WebAppWeb.AgentTranscript.transcript_items(session) == []
    assert WebAppWeb.AgentTranscript.partial_items(session) == []
  end

  test "groups live work and keeps the settled final reply outside it" do
    user = %{id: "user", kind: :message, role: :user, text: "Fix it"}
    progress = %{id: "progress", kind: :message, role: :agent, text: "I will inspect it"}

    trace = %{
      id: "tool",
      kind: :tool,
      tool: %{name: "bash", args: "pwd", result: nil, error: false}
    }

    final = %{id: "final", kind: :message, role: :agent, text: "Fixed"}

    assert [
             ^user,
             %{kind: :work_turn, active?: false, messages: [^progress], traces: [^trace]},
             ^final
           ] =
             WebAppWeb.AgentLive.work_turn_items([user, progress, trace, final], [], false)

    assert [
             ^user,
             %{kind: :work_turn, active?: true, messages: [^progress, ^final], traces: [^trace]}
           ] =
             WebAppWeb.AgentLive.work_turn_items([user, progress, trace], [final], true)
  end

  test "renders a work disclosure with nested activity" do
    html =
      render_component(&WebAppWeb.AgentLive.transcript_item/1,
        id: "work-user-settled",
        item: %{
          kind: :work_turn,
          active?: false,
          messages: [%{id: "progress", kind: :message, role: :agent, text: "I will inspect it"}],
          traces: [
            %{
              id: "tool",
              kind: :tool,
              tool: %{name: "bash", args: "pwd", result: nil, error: false}
            }
          ]
        }
      )

    assert html =~ "Worked"
    assert html =~ "Activity (1)"
    assert html =~ "data-copy-text=\"I will inspect it\""
    assert html =~ "hero-square-2-stack"
    refute html =~ "border-b border-base-content/10"
    refute html =~ "bg-base-content/5 p-3"
  end

  test "shows copy controls below every user and agent text" do
    user_html =
      render_component(&WebAppWeb.AgentLive.transcript_item/1,
        id: "user-message",
        item: %{kind: :message, role: :user, text: "Fix it"}
      )

    final_html =
      render_component(&WebAppWeb.AgentLive.transcript_item/1,
        id: "agent-message",
        item: %{kind: :message, role: :agent, text: "Fixed"}
      )

    progress_html =
      render_component(&WebAppWeb.AgentLive.transcript_item/1,
        id: "progress-message",
        item: %{kind: :message, role: :agent, text: "I will inspect it"}
      )

    assert user_html =~ "phx-hook=\"MessageCopy\""
    assert user_html =~ "data-copy-text=\"Fix it\""
    assert user_html =~ "hero-square-2-stack"
    assert user_html =~ "self-end"
    assert final_html =~ "phx-hook=\"MessageCopy\""
    assert final_html =~ "data-copy-text=\"Fixed\""
    refute final_html =~ "self-end"
    assert progress_html =~ "phx-hook=\"MessageCopy\""
    assert progress_html =~ "data-copy-text=\"I will inspect it\""
  end

  test "renders agent replies without a message bubble" do
    html =
      render_component(&WebAppWeb.AgentLive.transcript_item/1,
        id: "agent-message",
        item: %{kind: :message, role: :agent, text: "Done"}
      )

    refute html =~ "max-w-[72ch]"
    refute html =~ "rounded-2xl"
  end

  test "shows native feedback after copying a message", %{conn: conn, id: id} do
    {:ok, view, _html} = live(conn, ~p"/sessions/#{id}")

    assert has_element?(view, "[phx-hook='MessageCopy'][data-copy-text='First prompt']")
    assert has_element?(view, "[phx-hook='MessageCopy'][data-copy-text='First reply']")

    assert render_click(view, "message_copied") =~ "Message copied"
    assert render_click(view, "message_copy_failed") =~ "Message could not be copied"
  end

  test "renders discovered slash commands when the composer starts with a slash", %{
    conn: conn,
    id: id
  } do
    {:ok, view, _html} = live(conn, ~p"/sessions/#{id}")

    assert has_element?(view, "#composer-form")
    assert has_element?(view, "#slash-command-picker[hidden]")

    view
    |> form("#composer-form", composer: %{message: "/"})
    |> render_change()

    assert has_element?(view, "#slash-command-picker:not([hidden])")
    assert has_element?(view, "#slash-command-plan[title$='.pi/prompts/plan.md']")
  end

  test "submits settled browser chat input without ownership or a Send button", %{
    conn: conn,
    id: id,
    root: root
  } do
    :owner = AgentSession.claim(id, self())
    {:ok, view, _html} = live(conn, ~p"/sessions/#{id}")

    refute has_element?(view, "button[value='send']")
    refute has_element?(view, "button[value='later']")
    refute has_element?(view, "[phx-click='takeover']")

    view
    |> form("#composer-form", composer: %{message: "Review this"})
    |> render_submit()

    assert command_types(root) |> Enum.member?("prompt")
  end

  test "queues normal input while active, keeps Steer immediate, and clears processed queue", %{
    conn: conn,
    id: id,
    root: root
  } do
    {:ok, view, _html} = live(conn, ~p"/sessions/#{id}")
    assert :ok = AgentSession.command(id, %{"type" => "trigger_active"})
    sync_snapshot(view, id)
    assert has_element?(view, "button[value='steer']")

    assert :ok = AgentSession.command(id, %{"type" => "queue_steering"})
    sync_snapshot(view, id)
    assert has_element?(view, "#queued-steering", "Work on the design")

    view
    |> form("#composer-form", composer: %{message: "Run the tests"})
    |> render_submit()

    assert List.last(command_types(root)) == "follow_up"
    assert :ok = AgentSession.command(id, %{"type" => "queue_follow_up"})
    sync_snapshot(view, id)
    assert has_element?(view, "#queued-follow-up")
    assert has_element?(view, "#queued-follow-up", "Run the tests")

    render_submit(view, "compose", %{
      "composer" => %{"message" => "Stop here"},
      "behavior" => "steer"
    })

    assert List.last(command_types(root)) == "steer"

    assert :ok = AgentSession.command(id, %{"type" => "clear_follow_up"})
    sync_snapshot(view, id)
    refute has_element?(view, "#queued-follow-up")
  end

  test "applies the next delta and resynchronizes after a sequence gap", %{conn: conn, id: id} do
    {:ok, view, _html} = live(conn, ~p"/sessions/#{id}")
    %{sequence: sequence} = AgentSession.snapshot_with_sequence(id)

    send(view.pid, {
      :agent_update,
      id,
      sequence + 1,
      {:event,
       %{
         "type" => "message_end",
         "message" => %{
           "role" => "assistant",
           "content" => [%{"type" => "text", "text" => "incremental response"}]
         }
       }}
    })

    assert render(view) =~ "incremental response"

    send(view.pid, {
      :agent_update,
      id,
      sequence + 3,
      {:event,
       %{
         "type" => "message_end",
         "message" => %{
           "role" => "assistant",
           "content" => [%{"type" => "text", "text" => "out of sequence"}]
         }
       }}
    })

    refute render(view) =~ "out of sequence"
  end

  test "switches model and thinking level from the composer controls", %{
    conn: conn,
    id: id,
    root: root
  } do
    {:ok, view, _html} = live(conn, ~p"/sessions/#{id}")

    assert has_element?(view, "#composer-box")
    assert has_element?(view, "#composer-box .flex-nowrap")
    assert has_element?(view, "#model-select.max-w-36")
    assert has_element?(view, "#model-select option[selected]", "Claude Sonnet")
    assert has_element?(view, "#thinking-level-select option[selected]", "Medium")

    view |> element("#model-select") |> render_change(%{"model" => "openai/gpt-5.6"})

    assert has_element?(view, "#model-select option[selected]", "GPT-5.6")
    assert has_element?(view, "#thinking-level-select option", "High")
    refute has_element?(view, "#thinking-level-select option", "Medium")

    view |> element("#thinking-level-select") |> render_change(%{"level" => "high"})

    assert has_element?(view, "#thinking-level-select option[selected]", "High")

    commands =
      root
      |> Path.join("commands.jsonl")
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    assert Enum.any?(commands, fn command ->
             command["type"] == "set_model" and command["provider"] == "openai" and
               command["modelId"] == "gpt-5.6"
           end)

    assert Enum.any?(commands, fn command ->
             command["type"] == "set_thinking_level" and command["level"] == "high"
           end)
  end

  test "unsubscribes and clears the previous session after navigation", %{conn: conn, id: id} do
    {:ok, view, _html} = live(conn, ~p"/sessions/#{id}")

    render_patch(view, "/sessions/missing")

    refute Enum.any?(Registry.lookup(WebApp.SubscriberRegistry, id), fn {pid, _value} ->
             pid == view.pid
           end)

    send(view.pid, {
      :agent_update,
      id,
      1,
      {:event,
       %{
         "type" => "message_end",
         "message" => %{"role" => "assistant", "content" => "stale response"}
       }}
    })

    refute render(view) =~ "stale response"
  end

  test "aborts and restores queued messages to the composer", %{conn: conn, id: id} do
    {:ok, view, _html} = live(conn, ~p"/sessions/#{id}")
    assert :ok = AgentSession.command(id, %{"type" => "trigger_active"})
    assert :ok = AgentSession.command(id, %{"type" => "queue_steering"})
    sync_snapshot(view, id)

    render_hook(view, "abort_and_restore_queue")

    assert render(view) =~ "Work on the design"
    refute has_element?(view, "#queued-steering")
  end

  test "opens and closes the mobile session drawer", %{conn: conn, id: id} do
    {:ok, view, _html} = live(conn, ~p"/sessions/#{id}")

    assert has_element?(
             view,
             "#mobile-menu-button[aria-expanded='false'][aria-label='Open menu']"
           )

    refute has_element?(view, "#mobile-sidebar-backdrop")

    view |> element("#mobile-menu-button") |> render_click()

    assert has_element?(
             view,
             "#mobile-menu-button[aria-expanded='true'][aria-label='Close menu']"
           )

    assert has_element?(view, "#mobile-sidebar-backdrop")

    render_patch(view, ~p"/sessions/#{id}")

    refute has_element?(view, "#mobile-sidebar-backdrop")

    view |> element("#mobile-menu-button") |> render_click()
    view |> element("#mobile-sidebar-backdrop") |> render_click()

    refute has_element?(view, "#mobile-sidebar-backdrop")
  end

  defp sync_snapshot(view, id) do
    send(view.pid, {:agent_update, id, 1_000_000_000, :stale})
    _ = :sys.get_state(view.pid)
  end

  defp command_types(root) do
    root
    |> Path.join("commands.jsonl")
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
    |> Enum.map(& &1["type"])
  end
end
