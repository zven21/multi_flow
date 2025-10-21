# MultiFlow 🌊

> Make Ecto.Multi flow like water

[![Hex.pm](https://img.shields.io/hexpm/v/multi_flow.svg)](https://hex.pm/packages/multi_flow)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/multi_flow/)
[![License](https://img.shields.io/hexpm/l/multi_flow.svg)](https://github.com/zven21/multi_flow/blob/main/LICENSE)

A DSL and Builder pattern wrapper for `Ecto.Multi` that makes database transactions elegant, readable, and maintainable.

## Why MultiFlow?

Working with `Ecto.Multi` is powerful, but the syntax can become verbose and hard to follow. MultiFlow provides two elegant approaches:

### Before (Raw Ecto.Multi)

```elixir
Multi.new()
|> Multi.insert(:order, order_changeset)
|> Multi.run(:items, fn repo, %{order: order} ->
  items
  |> Enum.map(&create_item_changeset(&1, order))
  |> Enum.reduce(Multi.new(), fn changeset, multi ->
    Multi.insert(multi, {:item, changeset.changes.uuid}, changeset)
  end)
  |> repo.transaction()
  |> case do
    {:ok, items} -> {:ok, Map.values(items)}
    {:error, _failed_operation, changeset, _changes} -> {:error, changeset}
  end
end)
|> Multi.run(:delivery, fn repo, %{order: order} ->
  create_delivery(order)
end)
|> Repo.transaction()
```

### After (MultiFlow DSL)

```elixir
use MultiFlow

transaction do
  step :order, insert(order_changeset)
  
  step :items, fn %{order: order} ->
    items
    |> Enum.map(&create_item_changeset(&1, order))
    |> insert_all()
  end
  
  step :delivery, fn %{order: order} ->
    create_delivery(order)
  end
end
```

### Or (MultiFlow Builder)

```elixir
MultiFlow.new()
|> add_step(:order, insert: order_changeset)
|> add_step(:items, fn %{order: order} ->
  Enum.map(items, &create_item_changeset(&1, order))
end)
|> add_step(:delivery, &create_delivery/1, deps: [:order])
|> execute()
```

## Features

- 🌊 **Flow naturally** - Write transactions that read like prose
- 🎯 **DSL & Builder** - Choose your style: declarative DSL or functional builder
- 🔗 **Dependency tracking** - Automatic step dependency management
- 🛡️ **Type safe** - Full Dialyzer support
- 📝 **Readable** - Code that explains itself
- 🧪 **Testable** - Easy to test individual steps
- 🚀 **Zero overhead** - Compiles to raw `Ecto.Multi`

## Installation

Add `multi_flow` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:multi_flow, "~> 1.0"}
  ]
end
```

## Quick Start

### DSL Style

```elixir
defmodule MyApp.Orders do
  use MultiFlow
  
  def create_order(attrs, items_attrs) do
    transaction do
      # Step 1: Create order
      step :order, insert(Order.changeset(%Order{}, attrs))
      
      # Step 2: Create items (depends on order)
      step :items, fn %{order: order} ->
        items_attrs
        |> Enum.map(&OrderItem.changeset(%OrderItem{}, &1, order))
        |> insert_all()
      end
      
      # Step 3: Update inventory
      step :update_inventory, fn %{items: items} ->
        update_inventory(items)
      end
      
      # Step 4: Send notification
      step :notify, fn %{order: order} ->
        send_order_confirmation(order)
      end
    end
  end
end
```

### Builder Style

```elixir
defmodule MyApp.Orders do
  alias MultiFlow, as: MF
  
  def create_order(attrs, items_attrs) do
    MF.new()
    |> MF.add_step(:order, insert: Order.changeset(%Order{}, attrs))
    |> MF.add_step(:items, fn %{order: order} ->
      Enum.map(items_attrs, &OrderItem.changeset(%OrderItem{}, &1, order))
    end)
    |> MF.add_step(:update_inventory, &update_inventory/1, deps: [:items])
    |> MF.add_step(:notify, &send_order_confirmation/1, deps: [:order])
    |> MF.execute()
  end
end
```

## Real-World Example

Here's a complete sales order creation with error handling:

```elixir
defmodule MyApp.Sales do
  use MultiFlow
  
  def create_sales_order(order_attrs, items_attrs, delivery_attrs) do
    transaction do
      # Validate customer
      step :customer, fn _ ->
        get_customer(order_attrs.customer_id)
      end
      
      # Create order
      step :order, fn %{customer: customer} ->
        order_attrs
        |> Map.put(:customer_name, customer.name)
        |> create_order()
      end
      
      # Create order items
      step :items, fn %{order: order} ->
        items_attrs
        |> Enum.map(&prepare_item(&1, order))
        |> create_items()
      end
      
      # Calculate totals
      step :totals, fn %{items: items} ->
        calculate_totals(items)
      end
      
      # Update order with totals
      step :update_order, fn %{order: order, totals: totals} ->
        update_order(order, totals)
      end
      
      # Create delivery
      step :delivery, fn %{order: order} ->
        create_delivery(order, delivery_attrs)
      end
      
      # Check inventory
      step :check_inventory, fn %{items: items} ->
        check_and_reserve_inventory(items)
      end
      
      # Send notifications
      step :notify, fn %{order: order, customer: customer} ->
        send_notifications(order, customer)
      end
    end
  end
end
```

## Error Handling

MultiFlow preserves `Ecto.Multi`'s excellent error handling:

```elixir
case create_sales_order(attrs, items, delivery) do
  {:ok, result} ->
    # Success! All steps completed
    %{
      order: result.order,
      items: result.items,
      delivery: result.delivery
    }
    
  {:error, failed_step, changeset, changes_so_far} ->
    # Handle error
    Logger.error("Failed at step: #{failed_step}")
    {:error, changeset}
end
```

## Documentation

- [Getting Started Guide](guides/getting_started.md)
- [DSL Guide](guides/dsl_guide.md)
- [Builder Guide](guides/builder_guide.md)
- [Real World Examples](guides/real_world_examples.md)
- [API Documentation](https://hexdocs.pm/multi_flow/)

## When to Use MultiFlow?

### Use MultiFlow when:

- ✅ You have complex multi-step transactions
- ✅ You want more readable transaction code
- ✅ You need to test transaction steps individually
- ✅ You want better code organization

### Stick with raw Ecto.Multi when:

- ⚠️ You have very simple transactions (1-2 steps)
- ⚠️ You need maximum performance (though difference is negligible)
- ⚠️ Your team prefers explicit over implicit

## Performance

MultiFlow compiles to raw `Ecto.Multi` operations with zero runtime overhead. The abstractions are purely compile-time.

```elixir
# This MultiFlow code:
transaction do
  step :order, insert(changeset)
  step :items, &create_items/1
end

# Compiles to:
Multi.new()
|> Multi.insert(:order, changeset)
|> Multi.run(:items, fn _repo, changes -> create_items(changes) end)
|> Repo.transaction()
```

## Comparison

| Feature | Raw Ecto.Multi | MultiFlow DSL | MultiFlow Builder |
|---------|----------------|---------------|-------------------|
| Readability | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Verbosity | High | Low | Medium |
| Testability | Good | Excellent | Excellent |
| Learning Curve | Medium | Low | Low |
| Flexibility | High | High | Very High |
| Performance | Fast | Fast | Fast |

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

Created by [zven21](https://github.com/zven21)

Inspired by:
- [Ecto.Multi](https://hexdocs.pm/ecto/Ecto.Multi.html)
- [Commanded.Aggregate.Multi](https://hexdocs.pm/commanded/Commanded.Aggregate.Multi.html)
- Railway Oriented Programming

---

**Make your Ecto.Multi flow like water** 🌊
