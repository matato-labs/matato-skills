defmodule WebApp.FileLogConfigTest do
  use ExUnit.Case, async: true

  test "does not configure the rotating file log handler in the test environment" do
    assert Application.get_env(:web_app, :logger) == nil
    refute Enum.any?(:logger.get_handler_config(), &match?(%{id: :file_log}, &1))
  end
end
