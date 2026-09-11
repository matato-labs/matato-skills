defmodule WebApp.AutomationTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias WebApp.{Automation, AutomationRunner, AutomationScheduler}

  setup do
    AutomationScheduler.replace([])
    :ok
  end

  test "loads automations and preserves daily sessions" do
    path = temp_path()

    File.write!(path, """
    {"automations":[
      {"jobName":"enabled","enabled":true,"schedule":"*/5 * * * * *","userPrompt":"Run it","dailySession":true,"model":"model","thinkingLevel":"low"},
      {"jobName":"disabled","enabled":false,"schedule":"* * * * *","userPrompt":"Ignore it","model":"model","thinkingLevel":"off"}
    ]}
    """)

    assert {:ok, [automation, disabled]} = Automation.load(path)
    assert automation.job_name == "enabled"
    assert automation.daily_session
    refute disabled.enabled
  end

  test "logs the failed automation and reason" do
    job_name = "missing-#{System.unique_integer([:positive])}"

    log = capture_log(fn -> AutomationRunner.run(automation(job_name, "* * * * *")) end)

    assert log =~ "Automation failed: #{job_name}. Reason: Skill not found: #{job_name}"
  end

  test "validates every schedule before atomically replacing enabled jobs" do
    previous = automation("previous", "*/5 * * * * *")
    invalid_disabled = %{automation("disabled", "not a cron expression") | enabled: false}

    assert :ok = AutomationScheduler.replace([previous])

    assert {:error, "Invalid schedule for disabled: " <> _reason} =
             AutomationScheduler.replace([automation("next", "* * * * * *"), invalid_disabled])

    assert [{_, job}] = AutomationScheduler.jobs()
    assert {AutomationRunner, :run, [%{job_name: "previous"}]} = job.task
  end

  test "replaces schedules with enabled automations only" do
    disabled = %{automation("disabled", "* * * * *") | enabled: false}

    assert :ok = AutomationScheduler.replace([automation("enabled", "* * * * *"), disabled])

    assert [{_, %{task: {AutomationRunner, :run, [%{job_name: "enabled"}]}}}] =
             AutomationScheduler.jobs()
  end

  test "uses the seconds parser for six-field schedules" do
    assert :ok = AutomationScheduler.replace([automation("seconds", "*/5 * * * * *")])

    assert [{_, job}] = AutomationScheduler.jobs()
    assert inspect(job.schedule) == "~e[*/5 * * * * * *]e"
  end

  test "watcher boot-loads, handles atomic replacement, skips unchanged content, retains invalid config, and clears missing config" do
    path = temp_path()
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, config("boot"))
    original_path = restart_watcher(path)
    on_exit(fn -> restart_watcher(original_path) end)

    _ = :sys.get_state(WebApp.AutomationWatcher)
    assert scheduled?("boot")

    replacement = path <> ".new"
    File.write!(replacement, config("replacement"))
    File.rename!(replacement, path)
    reload_watcher(path)
    assert scheduled?("replacement")

    jobs = AutomationScheduler.jobs()
    File.write!(path, config("replacement"))
    reload_watcher(path)
    assert AutomationScheduler.jobs() == jobs

    File.write!(path, config("invalid", "not a cron expression"))
    reload_watcher(path)
    assert AutomationScheduler.jobs() == jobs

    File.rm!(path)
    reload_watcher(path)
    assert AutomationScheduler.jobs() == []
  end

  test "empty pre-script output skips Pi and post-script" do
    job_name = "automation-#{System.unique_integer([:positive])}"
    skill_path = Path.join([System.user_home!(), ".pi", "agent", "skills", job_name])
    pi_marker = temp_path()
    post_marker = temp_path()
    pi_dir = Path.join(System.tmp_dir!(), "pi-#{System.unique_integer([:positive])}")
    pi_path = Path.join(pi_dir, "pi")
    File.mkdir_p!(Path.join(skill_path, "scripts"))
    File.mkdir_p!(pi_dir)
    File.write!(Path.join(skill_path, "scripts/preScript.ts"), "console.log()")

    File.write!(
      Path.join(skill_path, "scripts/postScript.ts"),
      "await Bun.write(#{inspect(post_marker)}, \"post\")"
    )

    File.write!(
      pi_path,
      "#!/bin/sh\ntouch #{pi_marker}\nprintf '{\"type\":\"agent_settled\"}\\n'\n"
    )

    File.chmod!(pi_path, 0o755)
    original_path = System.get_env("PATH")
    System.put_env("PATH", "#{pi_dir}:#{original_path}")

    on_exit(fn ->
      System.put_env("PATH", original_path)
      File.rm_rf!(skill_path)
      File.rm(pi_marker)
      File.rm(post_marker)
      File.rm_rf!(pi_dir)
    end)

    AutomationRunner.run(automation(job_name, "* * * * *"))
    refute File.exists?(pi_marker)
    refute File.exists?(post_marker)
  end

  test "runs an agent when the pre-script returns work" do
    job_name = "automation-#{System.unique_integer([:positive])}"
    skill_path = Path.join([System.user_home!(), ".pi", "agent", "skills", job_name])
    pi_dir = Path.join(System.tmp_dir!(), "pi-#{System.unique_integer([:positive])}")
    pi_path = Path.join(pi_dir, "pi")
    pi_marker = temp_path()
    File.mkdir_p!(Path.join(skill_path, "scripts"))
    File.mkdir_p!(pi_dir)
    File.write!(Path.join(skill_path, "scripts/preScript.ts"), "console.log(\"work\")")

    File.write!(
      pi_path,
      "#!/bin/sh\ntouch #{pi_marker}\nprintf '%s\\n' '{\"type\":\"tool_execution_start\",\"toolName\":\"bash\"}' '{\"type\":\"tool_execution_end\",\"toolName\":\"bash\",\"isError\":false}' '{\"type\":\"agent_settled\"}'\n"
    )

    File.chmod!(pi_path, 0o755)
    original_path = System.get_env("PATH")
    System.put_env("PATH", "#{pi_dir}:#{original_path}")

    on_exit(fn ->
      System.put_env("PATH", original_path)
      File.rm_rf!(skill_path)
      File.rm(pi_marker)
      File.rm_rf!(pi_dir)
    end)

    AutomationRunner.run(automation(job_name, "* * * * *"))
    assert File.exists?(pi_marker)
  end

  test "rejects malformed automations" do
    path = temp_path()
    File.write!(path, ~s({"automations":[{"jobName":"missing fields"}]}))
    assert {:error, "Invalid automations configuration"} = Automation.load(path)
  end

  defp restart_watcher(path) do
    original_path = Application.fetch_env!(:web_app, :automations_config_path)
    Application.put_env(:web_app, :automations_config_path, path)
    :ok = Supervisor.terminate_child(WebApp.Supervisor, WebApp.AutomationWatcher)
    {:ok, _pid} = Supervisor.restart_child(WebApp.Supervisor, WebApp.AutomationWatcher)
    original_path
  end

  defp scheduled?(job_name) do
    Enum.any?(AutomationScheduler.jobs(), fn {_, job} ->
      match?({AutomationRunner, :run, [%{job_name: ^job_name}]}, job.task)
    end)
  end

  defp reload_watcher(path) do
    watcher = :sys.get_state(WebApp.AutomationWatcher).watcher
    send(WebApp.AutomationWatcher, {:file_event, watcher, {path, [:modified]}})
    %{reload_ref: reload_ref, timer: timer} = :sys.get_state(WebApp.AutomationWatcher)
    Process.cancel_timer(timer)
    send(WebApp.AutomationWatcher, {:reload, reload_ref})
    _ = :sys.get_state(WebApp.AutomationWatcher)
  end

  defp automation(job_name, schedule) do
    %Automation{
      job_name: job_name,
      enabled: true,
      schedule: schedule,
      user_prompt: "Run it",
      daily_session: false,
      model: "model",
      thinking_level: "off"
    }
  end

  defp config(job_name, schedule \\ "* * * * * *") do
    ~s({"automations":[{"jobName":"#{job_name}","enabled":true,"schedule":"#{schedule}","userPrompt":"Run it","model":"model","thinkingLevel":"off"}]})
  end

  defp temp_path do
    suffix = Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)
    Path.join(System.tmp_dir!(), "automations-#{suffix}.json")
  end
end
