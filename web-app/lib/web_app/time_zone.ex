defmodule WebApp.TimeZone do
  @default "Europe/Berlin"

  def configured, do: System.get_env("WEB_APP_TIME_ZONE", @default)
end
