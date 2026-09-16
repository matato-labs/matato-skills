defmodule WebApp.TimeZoneTest do
  use ExUnit.Case, async: true

  describe "configured/1" do
    test "uses Berlin when no time zone is configured" do
      assert WebApp.TimeZone.configured(nil) == "Europe/Berlin"
      assert Application.fetch_env!(:web_app, :time_zone) == "Europe/Berlin"
      assert {:ok, %DateTime{time_zone: "Europe/Berlin"}} = DateTime.now("Europe/Berlin")
    end

    test "uses the configured time zone" do
      assert WebApp.TimeZone.configured("America/New_York") == "America/New_York"
    end
  end
end
