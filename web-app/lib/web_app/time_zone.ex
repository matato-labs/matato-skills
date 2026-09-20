defmodule WebApp.TimeZone do
  @default "Europe/Berlin"

  def configured do
    case System.get_env("WEB_APP_TIME_ZONE", @default) |> String.trim() do
      "" -> @default
      time_zone -> time_zone
    end
  end
end
