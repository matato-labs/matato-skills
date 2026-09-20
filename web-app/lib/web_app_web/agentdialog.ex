defmodule WebAppWeb.AgentDialog do
  def response(%{"id" => id, "method" => "confirm"}, params) do
    %{"type" => "extension_ui_response", "id" => id, "confirmed" => params["answer"] == "true"}
  end

  def response(%{"id" => id}, %{"cancel" => "true"}),
    do: %{"type" => "extension_ui_response", "id" => id, "cancelled" => true}

  def response(%{"id" => id}, %{"dialog" => params}),
    do: %{"type" => "extension_ui_response", "id" => id, "value" => params["value"]}

  def response(%{"id" => id}, params),
    do: %{"type" => "extension_ui_response", "id" => id, "value" => params["value"]}
end
