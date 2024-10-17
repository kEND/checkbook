defmodule CheckbookTest do
  use ExUnit.Case
  doctest Checkbook

  test "greets the world" do
    assert Checkbook.hello() == :world
  end
end
