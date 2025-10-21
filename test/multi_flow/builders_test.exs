defmodule MultiFlow.BuildersTest do
  use ExUnit.Case
  
  import MultiFlow.Builders
  alias Ecto.Multi
  
  describe "run_step/3" do
    test "adds a run step to multi" do
      multi = 
        Multi.new()
        |> run_step(:test, fn _changes ->
          {:ok, %{result: "success"}}
        end)
      
      assert %Multi{} = multi
    end
  end
  
  describe "conditional_step/4" do
    test "adds step when condition is true" do
      multi = 
        Multi.new()
        |> conditional_step(true, :step, fn _ -> {:ok, %{added: true}} end)
      
      # Multi includes the step
      assert %Multi{operations: ops} = multi
      assert length(ops) == 1
    end
    
    test "skips step when condition is false" do
      multi = 
        Multi.new()
        |> conditional_step(false, :step, fn _ -> {:ok, %{added: true}} end)
      
      # Multi is empty
      assert %Multi{operations: ops} = multi
      assert length(ops) == 0
    end
  end
  
  describe "merge_multi/2" do
    test "merges two multis" do
      multi1 = Multi.new() |> run_step(:step1, fn _ -> {:ok, 1} end)
      multi2 = Multi.new() |> run_step(:step2, fn _ -> {:ok, 2} end)
      
      merged = merge_multi(multi1, multi2)
      
      assert %Multi{operations: ops} = merged
      assert length(ops) == 2
    end
  end
end

