defmodule MultiFlow.Utils do
  @moduledoc """
  Utility functions for MultiFlow.
  """

  @doc """
  Safely gets a value from nested changes.
  
  ## Example
  
      get_in_changes(changes, [:create_order, :id])
  """
  def get_in_changes(changes, path) do
    get_in(changes, path)
  end

  @doc """
  Merges transaction results from multiple sources.
  """
  def merge_results(results) when is_list(results) do
    Enum.reduce(results, %{}, fn
      {:ok, result}, acc -> Map.merge(acc, result)
      {:error, _}, acc -> acc
    end)
  end

  @doc """
  Formats a transaction error for display.
  """
  def format_error({:error, failed_operation, failed_value, _changes}) do
    """
    Transaction failed at step: #{failed_operation}
    Error: #{inspect(failed_value)}
    """
  end
  
  def format_error(error), do: inspect(error)
end

