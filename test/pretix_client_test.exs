defmodule PretixClientTest do
  use ExUnit.Case
  doctest PretixClient

  test "greets the world" do
    assert PretixClient.hello() == :world
  end
end
