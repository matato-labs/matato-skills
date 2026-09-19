defmodule WebApp.ArchitectureTest do
  use ExUnit.Case, async: true

  @domains [WebApp.Automations, WebApp.Bots, WebApp.Messages, WebApp.Sessions]

  @controller_domains %{
    WebAppWeb.AutomationController => WebApp.Automations,
    WebAppWeb.BotController => WebApp.Bots,
    WebAppWeb.MessageController => WebApp.Messages,
    WebAppWeb.SessionController => WebApp.Sessions
  }

  test "each domain controller only calls its matching domain facade" do
    Enum.each(@controller_domains, fn {controller, domain} ->
      {:ok, {^controller, [imports: imports]}} =
        controller |> :code.which() |> :beam_lib.chunks([:imports])

      invalid_calls =
        imports
        |> Enum.map(&elem(&1, 0))
        |> Enum.uniq()
        |> Enum.filter(&application_module?/1)
        |> Enum.reject(&(&1 == domain or web_module?(&1)))

      assert invalid_calls == [],
             "#{inspect(controller)} must only call #{inspect(domain)}, but calls #{inspect(invalid_calls)}"
    end)
  end

  test "domain internals are only called by their owning domain" do
    {:ok, modules} = :application.get_key(:web_app, :modules)

    invalid_calls =
      for source <- modules,
          target <- imports(source),
          owner = internal_owner(target),
          owner && not owned_by?(source, owner),
          uniq: true,
          do: {source, target}

    assert invalid_calls == [], "domain internals called externally: #{inspect(invalid_calls)}"
  end

  defp imports(module) do
    {:ok, {^module, [imports: imports]}} =
      module |> :code.which() |> :beam_lib.chunks([:imports])

    imports |> Enum.map(&elem(&1, 0)) |> Enum.uniq()
  end

  defp internal_owner(module) do
    Enum.find(@domains, fn domain ->
      String.starts_with?(Atom.to_string(module), Atom.to_string(domain) <> ".")
    end)
  end

  defp owned_by?(module, domain),
    do:
      module == domain or
        String.starts_with?(Atom.to_string(module), Atom.to_string(domain) <> ".")

  defp application_module?(module),
    do: module |> Atom.to_string() |> String.starts_with?("Elixir.WebApp")

  defp web_module?(module),
    do: module |> Atom.to_string() |> String.starts_with?("Elixir.WebAppWeb")
end
