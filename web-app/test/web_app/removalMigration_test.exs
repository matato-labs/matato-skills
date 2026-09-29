defmodule WebApp.RemovalMigrationTest do
  use ExUnit.Case, async: false

  alias WebApp.Data.Repo

  test "upgrades linked legacy data without losing ordinary jobs or transcripts" do
    root = Path.join(System.tmp_dir!(), "migration#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)

    repo =
      start_supervised!(
        {Repo, name: nil, database: Path.join(root, "fixture.sqlite3"), pool_size: 2}
      )

    previous = Repo.put_dynamic_repo(repo)

    try do
      upgrade_fixture(root, repo)
    after
      Repo.put_dynamic_repo(previous)
    end
  end

  defp upgrade_fixture(root, repo) do
    migrations = migrations()

    Ecto.Migrator.run(Repo, migrations, :up,
      to: 20_260_416_000_000,
      dynamic_repo: repo,
      log: false
    )

    Repo.query!("PRAGMA foreign_keys = ON")
    transcript = Path.join(root, "history.jsonl")
    File.write!(transcript, "{\"type\":\"session\",\"id\":\"history\"}\n")
    now = ~N[2026-09-29 00:00:00]
    bot = "11111111-1111-1111-1111-111111111111"

    Repo.insert_all("remote_sessions", [
      %{
        id: "historicalId",
        name: "Conversation",
        project_path: root,
        relative_project: ".",
        session_file: transcript,
        source: "bot_chat",
        status: "stopped",
        inserted_at: now,
        updated_at: now
      }
    ])

    Repo.insert_all("bots", [
      %{
        id: bot,
        name: "Research",
        role: "researcher",
        description: "Review work",
        chat_remote_session_id: "historicalId",
        background_remote_session_id: "backgroundId",
        inserted_at: now,
        updated_at: now
      }
    ])

    Repo.insert_all("messages", [
      %{
        id: "22222222-2222-2222-2222-222222222222",
        timestamp: now,
        sender_type: "bot",
        sender_id: bot,
        receiver_bot_id: bot,
        kind: "note",
        content: "Pending",
        sent_status: "pending",
        inserted_at: now,
        updated_at: now
      }
    ])

    insert_jobs(bot, now)
    before = Repo.query!("SELECT * FROM remote_sessions").rows

    Ecto.Migrator.run(Repo, migrations, :up,
      to: 20_260_929_000_001,
      dynamic_repo: repo,
      log: false
    )

    Repo.insert_all("channel_settings", [
      %{id: "telegram", enabled: 1, inserted_at: now, updated_at: now}
    ])

    Ecto.Migrator.run(Repo, migrations, :up, all: true, dynamic_repo: repo, log: false)
    assert_preserved(before, transcript)
  end

  defp insert_jobs(bot, now) do
    for {name, owner, skill} <- [
          {"ordinary", nil, false},
          {"associated", bot, false},
          {"telegram-inbox", bot, true},
          {"discord", nil, true}
        ] do
      Repo.insert_all("automations", [
        %{
          job_name: name,
          bot_id: owner,
          enabled: 1,
          schedule: "0 9 * * *",
          user_prompt: "Review",
          daily_session: 0,
          model: "model",
          thinking_level: "low",
          can_launch_sub_agents: 0,
          can_overlap: 0,
          use_skill: if(skill, do: 1, else: 0),
          monitor: 1,
          inserted_at: now,
          updated_at: now
        }
      ])
    end
  end

  defp assert_preserved(before, transcript) do
    assert [["associated"], ["ordinary"]] ==
             Repo.query!("SELECT job_name FROM automations ORDER BY job_name").rows

    refute Enum.any?(
             Repo.query!("PRAGMA table_info(automations)").rows,
             &(Enum.at(&1, 1) == "bot_id")
           )

    assert [] ==
             Repo.query!("SELECT name FROM sqlite_master WHERE name IN ('bots', 'messages')").rows

    assert [] == Repo.query!("PRAGMA foreign_key_check").rows
    assert before == Repo.query!("SELECT * FROM remote_sessions").rows
    assert File.read!(transcript) == "{\"type\":\"session\",\"id\":\"history\"}\n"

    assert [] ==
             Repo.query!("SELECT name FROM sqlite_master WHERE name = 'channel_settings'").rows
  end

  defp migrations do
    alias WebApp.Repo.Migrations

    migrations = [
      {20_260_411_000_000, Migrations.CreatePersistenceTables},
      {20_260_412_000_000, Migrations.AddUseSkillToAutomations},
      {20_260_413_000_000, Migrations.AddCanOverlapToAutomations},
      {20_260_414_000_000, Migrations.AddMonitorToAutomations},
      {20_260_415_000_000, Migrations.CreateBotsAndMessages},
      {20_260_416_000_000, Migrations.AddUniqueRemoteSessionFile},
      {20_260_929_000_000, Migrations.RemoveBotsAndMessages},
      {20_260_929_000_001, Migrations.CreateChannelSettings},
      {20_260_929_000_002, Migrations.RemoveChannelSettings}
    ]

    Enum.each(migrations, fn {version, module} ->
      unless Code.ensure_loaded?(module) do
        Application.app_dir(:web_app, "priv/repo/migrations/#{version}_*.exs")
        |> Path.wildcard()
        |> Enum.each(&Code.require_file/1)
      end
    end)

    migrations
  end
end
