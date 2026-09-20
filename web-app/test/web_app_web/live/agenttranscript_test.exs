defmodule WebAppWeb.AgentTranscriptTest do
  use WebAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "hides expanded skill content in the transcript" do
    message = %{
      "content" =>
        "<skill name=\"review\" location=\"/skills/review/SKILL.md\">\nReview instructions\n</skill>\n\nCheck the API"
    }

    assert WebAppWeb.AgentLive.display_message_text(message) == "/skill:review\n\nCheck the API"
  end

  test "omits tool activity missing from incomplete persisted and live transcript data" do
    session = %{
      WebApp.Sessions.State.new()
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
end
