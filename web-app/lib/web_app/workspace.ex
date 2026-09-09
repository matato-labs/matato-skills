defmodule WebApp.Workspace do
  @moduledoc "Canonical, read-only navigation within the configured workspace."

  def root do
    path = :web_app |> Application.fetch_env!(:workspace) |> Path.expand()

    case canonical(path) do
      {:ok, root} -> root
      {:error, reason} -> raise File.Error, reason: reason, action: "resolve", path: path
    end
  end

  def validate! do
    root = root()
    unless File.dir?(root), do: raise("WORKSPACE is not an accessible directory: #{root}")
    root
  end

  def directories(relative \\ ".") do
    directory = resolve(relative)

    directory
    |> File.ls!()
    |> Enum.sort()
    |> Enum.filter(&File.dir?(Path.join(directory, &1)))
    |> Enum.flat_map(fn name ->
      path = Path.join(directory, name)

      case authorize(path) do
        {:ok, canonical} -> [%{name: name, path: Path.relative_to(canonical, root())}]
        {:error, _reason} -> []
      end
    end)
  end

  def resolve(relative) when is_binary(relative) do
    relative
    |> then(&Path.join(root(), &1))
    |> authorize()
    |> case do
      {:ok, path} -> path
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  defp authorize(path) do
    with {:ok, canonical} <- canonical(path),
         true <- File.dir?(canonical),
         true <- inside?(canonical) do
      {:ok, canonical}
    else
      _ -> {:error, "Project must be an accessible directory inside WORKSPACE"}
    end
  end

  defp canonical(path) do
    case System.cmd("readlink", ["-f", "--", path], stderr_to_stdout: true) do
      {result, 0} -> {:ok, String.trim_trailing(result)}
      {error, _status} -> {:error, String.trim(error)}
    end
  end

  defp inside?(path) do
    root = root()
    path == root or String.starts_with?(path, root <> "/")
  end
end
