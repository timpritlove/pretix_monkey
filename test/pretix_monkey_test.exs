defmodule PretixMonkeyTest do
  use ExUnit.Case
  doctest PretixMonkey

  test "greets the world" do
    assert PretixMonkey.hello() == :world
  end
end
