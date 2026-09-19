defmodule WebApp.TimeZoneTest do
  use ExUnit.Case, async: false

  setup do
    previous_time_zone = System.get_env("WEB_APP_TIME_ZONE")

    on_exit(fn ->
      if previous_time_zone do
        System.put_env("WEB_APP_TIME_ZONE", previous_time_zone)
      else
        System.delete_env("WEB_APP_TIME_ZONE")
      end
    end)

    :ok
  end

  test "defaults automation schedules to Berlin" do
    System.delete_env("WEB_APP_TIME_ZONE")

    assert time_zone_config() == "Europe/Berlin"
  end

  test "uses the configured time zone for automation schedules" do
    System.put_env("WEB_APP_TIME_ZONE", "America/New_York")

    assert time_zone_config() == "America/New_York"
  end

  test "makes configured time zones available to the application" do
    assert Calendar.get_time_zone_database() == Tzdata.TimeZoneDatabase
    assert {:ok, %DateTime{time_zone: "Europe/Berlin"}} = DateTime.now("Europe/Berlin")
  end

  defp time_zone_config do
    config =
      Config.Reader.read!(Path.expand("../../config/runtime.exs", __DIR__), env: :test)

    web_app_config = Keyword.fetch!(config, :web_app)

    assert web_app_config[:time_zone] ==
             Keyword.fetch!(web_app_config, WebApp.Automations.Scheduler)[:timezone]

    web_app_config[:time_zone]
  end
end
