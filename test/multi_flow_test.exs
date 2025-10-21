defmodule MultiFlowTest do
  use ExUnit.Case
  doctest MultiFlow

  test "returns version" do
    assert MultiFlow.version() =~ ~r/\d+\.\d+\.\d+/
  end
end

