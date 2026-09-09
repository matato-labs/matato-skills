defmodule WebApp.Rpc.Framer do
  @moduledoc "Strict LF-only JSONL framing for arbitrary UTF-8 byte chunks."

  def push(buffer, chunk) when is_binary(buffer) and is_binary(chunk) do
    parts = :binary.split(buffer <> chunk, "\n", [:global])
    {lines, [rest]} = Enum.split(parts, -1)
    {Enum.map(lines, &strip_cr/1), rest}
  end

  def finish(""), do: []
  def finish(buffer), do: [strip_cr(buffer)]

  defp strip_cr(<<>>), do: <<>>

  defp strip_cr(line) do
    size = byte_size(line) - 1

    case line do
      <<body::binary-size(size), "\r">> -> body
      _line -> line
    end
  end
end
