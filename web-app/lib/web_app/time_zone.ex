defmodule WebApp.TimeZone do
  @default "Europe/Berlin"

  def default, do: @default

  def configured(nil), do: @default
  def configured(time_zone) when is_binary(time_zone), do: time_zone
end
