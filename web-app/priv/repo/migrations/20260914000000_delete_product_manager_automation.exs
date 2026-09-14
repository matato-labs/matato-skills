defmodule WebApp.Repo.Migrations.DeleteProductManagerAutomation do
  use Ecto.Migration

  def up, do: execute("DELETE FROM automations WHERE job_name = 'product-manager'")
  def down, do: :ok
end
