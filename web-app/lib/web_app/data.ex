defmodule WebApp.Data do
  use Boundary, top_level?: true, deps: [], exports: [Repo]

  def child_specs, do: [WebApp.Data.Repo]
end
