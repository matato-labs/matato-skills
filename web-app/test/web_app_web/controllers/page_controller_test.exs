defmodule WebAppWeb.PageControllerTest do
  use WebAppWeb.ConnCase

  test "project picker is ready to start a session", %{conn: conn} do
    document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()
    assert LazyHTML.filter(document, "#start-session-form") != []
    assert LazyHTML.filter(document, "#start-session-button") != []
  end
end
