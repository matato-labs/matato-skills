defmodule WebApp.Sessions.Transcript do
  alias WebApp.Sessions.State

  def load(%{"source" => "automation", "session_file" => path, "status" => status})
      when is_binary(path) do
    with :ok <- validate_path(path),
         {:ok, body} <- File.read(path) do
      messages =
        body
        |> String.split("\n", trim: true)
        |> Enum.flat_map(&message/1)

      state = State.new() |> State.hydrate(%{"messages" => messages})
      {:ok, %{state | status: status(status)}}
    else
      _reason -> {:error, :unavailable}
    end
  end

  def load(_metadata), do: {:error, :unavailable}

  defp message(line) do
    case Jason.decode(line) do
      {:ok, %{"type" => "message", "message" => message}} -> [message]
      _result -> []
    end
  end

  defp validate_path(path) do
    root = Path.join(Application.fetch_env!(:web_app, :automation_storage_path), "sessions")

    with {:ok, canonical_root} <- canonical(root),
         {:ok, canonical_path} <- canonical(path),
         true <- String.starts_with?(canonical_path, canonical_root <> "/"),
         true <- File.regular?(canonical_path) do
      :ok
    else
      _reason -> {:error, :invalid_path}
    end
  end

  defp canonical(path) do
    case System.cmd("readlink", ["-f", "--", path], stderr_to_stdout: true) do
      {canonical, 0} -> {:ok, String.trim(canonical)}
      {_error, _status} -> :error
    end
  end

  defp status("starting"), do: :starting
  defp status("working"), do: :working
  defp status("waiting_for_input"), do: :waiting_for_input
  defp status("retrying"), do: :retrying
  defp status("compacting"), do: :compacting
  defp status("settled"), do: :settled
  defp status("failed"), do: :failed
  defp status("interrupted"), do: :interrupted
  defp status("stopped"), do: :stopped
  defp status(_status), do: :failed
end
