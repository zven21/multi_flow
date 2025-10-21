# DSL Guide

The DSL provides a declarative way to define Ecto.Multi transactions.

## Basic Structure

```elixir
defmodule MyTransaction do
  use MultiFlow.DSL, repo: MyApp.Repo
  
  transaction "Transaction description" do
    step :step_name, :step_type do
      # step configuration
    end
  end
  
  # Helper functions
  defp helper_function(args) do
    # implementation
  end
end
```

## Step Types

### :run - Execute Custom Logic

```elixir
step :validate, :run do
  function &validate_input/2
end

defp validate_input(_repo, changes) do
  {:ok, %{validated: true}}
end
```

### :insert - Insert Single Record

```elixir
step :create_user, :insert do
  schema User
  builder &build_user/1
end

defp build_user(changes) do
  %User{name: changes.params.name}
end
```

### :insert_all - Bulk Insert

```elixir
step :create_items, :insert_all do
  schema OrderItem
  builder &build_items/1
end

defp build_items(changes) do
  Enum.map(changes.params.items, fn item ->
    %{order_id: changes.create_order.id, ...}
  end)
end
```

### :update_all - Bulk Update

```elixir
step :update_stock, :update_all do
  query &stock_query/1
  set &stock_changes/1
end

defp stock_query(changes) do
  from s in Stock, where: s.id in ^changes.item_ids
end

defp stock_changes(_changes) do
  [set: [qty: fragment("qty - 1")]]
end
```

## Advanced Features

### Error Handling

```elixir
step :send_notification, :run do
  function &send_email/2
  on_error :continue  # Don't rollback if this fails
end
```

### Retry Logic

```elixir
step :call_api, :run do
  function &call_external_api/2
  retry 3
end
```

### Dependencies

```elixir
step :second_step, :run do
  function &process/2
  depends_on :first_step
end
```

### Async Execution

```elixir
step :background_task, :run do
  function &process_async/2
  async true
end
```

## Complete Example

See [examples/sales_order.ex](../examples/sales_order.ex) for a complex real-world example.

