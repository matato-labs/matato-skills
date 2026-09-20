defmodule WebAppWeb.AgentModelTest do
  use ExUnit.Case, async: true

  alias WebAppWeb.AgentModel

  test "normalizes malformed model names" do
    assert AgentModel.normalize([%{"provider" => "anthropic", "id" => "claude", "name" => %{}}]) ==
             [
               %{"provider" => "anthropic", "id" => "claude", "name" => "claude"}
             ]
  end
end
