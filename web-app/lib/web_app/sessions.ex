defmodule WebApp.Sessions do
  import Kernel, except: [apply: 2]

  use Boundary, top_level?: true, deps: [WebApp.Data], exports: []

  alias WebApp.Sessions.{Agent, Catalog, Fanout, Registry, State, Store, Transcript, Workspace}

  def child_specs do
    [
      {Elixir.Registry, keys: :unique, name: WebApp.Sessions.ProcessRegistry},
      {Elixir.Registry, keys: :duplicate, name: WebApp.Sessions.SubscriberRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: WebApp.Sessions.AgentSupervisor},
      WebApp.Sessions.Registry
    ]
  end

  defdelegate validate_workspace!(), to: Workspace, as: :validate!
  defdelegate list(), to: Registry
  defdelegate subscribe(), to: Registry, as: :subscribe
  defdelegate create(relative), to: Registry
  defdelegate create(relative, options), to: Registry
  defdelegate open(id), to: Registry
  defdelegate open(id, identity), to: Registry
  defdelegate stop(id), to: Registry
  defdelegate delete(id), to: Registry
  defdelegate register_automation(name), to: Registry
  defdelegate complete_automation(id, status, result), to: Registry

  defdelegate register(attributes), to: Store
  defdelegate get(id), to: Store
  defdelegate load_automation_transcript(metadata), to: Transcript, as: :load

  defdelegate snapshot(id), to: Agent
  defdelegate snapshot_with_sequence(id), to: Agent
  defdelegate command(id, command), to: Agent
  defdelegate owner_command(id, owner, command), to: Agent
  defdelegate owner_command_and_await_settled(id, owner, command), to: Agent
  defdelegate claim(id, owner), to: Agent
  defdelegate release(id, owner), to: Agent
  defdelegate respond(id, response), to: Agent

  defdelegate subscribe_agent(id), to: Fanout, as: :subscribe
  defdelegate unsubscribe_agent(id), to: Fanout, as: :unsubscribe

  defdelegate workspace_directories(), to: Workspace, as: :directories
  defdelegate workspace_groups(records), to: Catalog
  defdelegate automation_groups(records, automations), to: Catalog
  defdelegate automation_runs(records, name), to: Catalog

  defdelegate clear_dialog(state), to: State
  defdelegate apply(state, event), to: State
  defdelegate partial_text(state), to: State
  defdelegate partial_thinking(state), to: State
end
