# Builder Guide

Builders provide a functional, composable way to construct Ecto.Multi transactions.

## Why Use Builders?

Builders are ideal when you need:

- **Conditional logic** - Different steps based on parameters
- **Dynamic composition** - Build transactions programmatically  
- **Maximum flexibility** - Full control over the flow
- **Reusable components** - Share transaction fragments

## Basic Usage

```elixir
import MultiFlow.Builders
alias Ecto.Multi

def create_order(params) do
  Multi.new()
  |> run_step(:validate, fn _ -> validate(params) end)
  |> insert_step(:order, Order, &build_order/1)
  |> insert_all_step(:items, OrderItem, &build_items/1)
  |> MyApp.Repo.transaction()
end
```

## Builder Functions

### run_step/3

Execute a custom function:

```elixir
multi
|> run_step(:step_name, fn changes ->
  {:ok, %{result: "success"}}
end)
```

### insert_step/4

Insert a single record:

```elixir
multi
|> insert_step(:user, User, fn changes ->
  %User{name: changes.params.name}
end)
```

### insert_all_step/4

Bulk insert records:

```elixir
multi
|> insert_all_step(:items, Item, fn changes ->
  [
    %{name: "Item 1"},
    %{name: "Item 2"}
  ]
end)
```

### update_step/3

Update a record:

```elixir
multi
|> update_step(:user, fn changes ->
  Ecto.Changeset.change(changes.user, %{updated: true})
end)
```

### update_all_step/4

Bulk update:

```elixir
multi
|> update_all_step(:stock,
  fn _ -> from(s in Stock, where: s.qty < 10) end,
  fn _ -> [set: [updated_at: DateTime.utc_now()]] end
)
```

### conditional_step/4

Conditional execution:

```elixir
multi
|> conditional_step(user.is_vip?, :vip_discount, fn changes ->
  {:ok, %{discount: 0.2}}
end)
```

### retry_step/5

Retry on failure:

```elixir
multi
|> retry_step(:api_call, 3, 1000, fn changes ->
  call_external_api(changes)
end)
```

## Advanced Patterns

### Reusable Fragments

```elixir
defmodule CommonSteps do
  import MultiFlow.Builders
  
  def add_customer_validation(multi, params) do
    multi
    |> run_step(:validate_customer, fn _ ->
      validate_customer(params.customer_id)
    end)
    |> run_step(:check_credit, fn _ ->
      check_customer_credit(params.customer_id)
    end)
  end
end

# Use in your transaction
Multi.new()
|> CommonSteps.add_customer_validation(params)
|> insert_step(:order, Order, &build_order/1)
```

### Grouping Steps

```elixir
multi
|> group(:order_creation, fn multi ->
  multi
  |> insert_step(:order, Order, &build_order/1)
  |> insert_all_step(:items, OrderItem, &build_items/1)
end)
|> group(:payment_processing, fn multi ->
  multi
  |> insert_step(:payment, Payment, &build_payment/1)
  |> update_step(:order, &mark_as_paid/1)
end)
```

### Tap for Side Effects

```elixir
multi
|> tap_step(:log_start, fn changes ->
  Logger.info("Transaction started")
  changes
end)
|> insert_step(:record, Record, &build/1)
|> tap_step(:log_end, fn changes ->
  Logger.info("Transaction completed")
  changes
end)
```

## Complete Example

See [examples/sales_order.ex](../examples/sales_order.ex) for a production-ready example using builders.

