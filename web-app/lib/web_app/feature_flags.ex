defmodule WebApp.FeatureFlags do
  @moduledoc "Runtime-configured presentation flags."

  @spec enabled?(atom()) :: boolean()
  def enabled?(flag) when is_atom(flag) do
    :web_app
    |> Application.get_env(:feature_flags, %{})
    |> Map.get(flag, false)
  end
end
