defmodule WebApp.Rpc.FramerTest do
  use ExUnit.Case, async: true

  alias WebApp.Rpc.Framer

  test "frames fragmented and combined LF records without splitting unicode separators" do
    {lines, buffer} = Framer.push("", "{\"text\":\"a\u2028b\"}\r\n{\"x\":")
    assert lines == ["{\"text\":\"a\u2028b\"}"]

    {lines, buffer} = Framer.push(buffer, "1}\n")
    assert lines == ["{\"x\":1}"]
    assert buffer == ""
  end

  test "finishes one unterminated record and strips only its trailing carriage return" do
    assert Framer.finish("record\r") == ["record"]
    assert Framer.finish("") == []
  end

  test "frames invalid UTF-8 without crashing before protocol validation" do
    assert Framer.push("", <<255, ?\r, ?\n>>) == {[<<255>>], ""}
  end
end
