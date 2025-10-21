# Real World Examples

This guide showcases real-world use cases for MultiFlow.

## Example 1: E-Commerce Order Processing

> Full code: [examples/sales_order.ex](../examples/sales_order.ex)

This example demonstrates a complete e-commerce order processing flow with:

- Order creation and validation
- Inventory management
- Payment processing
- Delivery management
- Invoice generation
- Conditional logic (immediate payment, immediate delivery)

**Why Builder instead of DSL?**

The sales order has many conditional branches:
- Maybe immediate payment
- Maybe immediate delivery
- Maybe auto invoice
- Different paths based on order status

**Key Features Demonstrated:**

```elixir
Multi.new()
# Phase 1: Validation
|> add_validation_phase(params)

# Phase 2: Core creation
|> add_creation_phase(params)

# Phase 3: Amount calculation
|> add_calculation_phase(params)

# Phase 4: Conditional steps ⭐
|> maybe_immediate_payment(params)
|> maybe_immediate_delivery(params)
|> maybe_generate_invoice(params)

# Phase 5: Updates
|> add_update_phase(params)

# Phase 6: Notifications
|> add_notification_phase(params)
```

**Conditional Step Example:**

```elixir
defp maybe_immediate_payment(multi, %{immediate_payment: true} = params) do
  multi
  |> insert_step(:payment, Payment, &build_payment/1)
  |> update_step(:order, &mark_as_paid/1)
end
defp maybe_immediate_payment(multi, _params), do: multi
```

## Example 2: User Registration (DSL)

Simple, straightforward flow - perfect for DSL:

```elixir
defmodule MyApp.RegisterUser do
  use MultiFlow.DSL, repo: MyApp.Repo
  
  transaction "User registration with profile and preferences" do
    step :validate, :run do
      description "Validate email and password"
      function &validate_input/2
    end
    
    step :create_user, :insert do
      description "Create user account"
      schema MyApp.Accounts.User
      builder &build_user/1
    end
    
    step :create_profile, :insert do
      description "Create user profile"
      schema MyApp.Accounts.Profile
      builder &build_profile/1
    end
    
    step :set_preferences, :insert do
      description "Set default preferences"
      schema MyApp.Accounts.Preferences
      builder &build_preferences/1
    end
    
    step :send_verification, :run do
      description "Send email verification"
      function &send_verification_email/2
      on_error :continue
    end
  end
  
  # ... implementation
end
```

## Example 3: Batch Import (Builder)

Processing bulk data with progress tracking:

```elixir
defmodule MyApp.ImportCustomers do
  import MultiFlow.Builders
  alias Ecto.Multi
  
  def execute(csv_data) do
    Multi.new()
    |> run_step(:parse_csv, fn _ ->
      parse_csv(csv_data)
    end)
    |> run_step(:validate_all, fn changes ->
      validate_records(changes.parse_csv)
    end)
    |> run_step(:deduplicate, fn changes ->
      remove_duplicates(changes.validate_all)
    end)
    |> insert_all_step(:import_customers, Customer, fn changes ->
      prepare_for_insert(changes.deduplicate)
    end)
    |> update_all_step(:update_existing,
      &existing_customers_query/1,
      &existing_customers_updates/1
    )
    |> tap_step(:log_results, fn changes ->
      {count, _} = changes.import_customers
      IO.puts("Imported #{count} customers")
      changes
    end)
    |> MyApp.Repo.transaction(timeout: :infinity)
  end
end
```

## Example 4: Complex Workflow (Builder)

When you need maximum flexibility:

```elixir
defmodule MyApp.ProcessComplexOrder do
  import MultiFlow.Builders
  alias Ecto.Multi
  
  def execute(params) do
    Multi.new()
    |> add_base_steps(params)
    |> branch_by_order_type(params.order_type)
    |> add_payment_steps(params)
    |> MyApp.Repo.transaction()
  end
  
  defp branch_by_order_type(multi, :regular) do
    multi
    |> run_step(:process_regular, &process_regular_order/1)
  end
  
  defp branch_by_order_type(multi, :presale) do
    multi
    |> run_step(:reserve_inventory, &reserve_inventory/1)
    |> run_step(:schedule_delivery, &schedule_delivery/1)
  end
  
  defp branch_by_order_type(multi, :dropship) do
    multi
    |> run_step(:notify_supplier, &notify_supplier/1)
    |> run_step(:create_po, &create_purchase_order/1)
  end
end
```

## Example 5: Combining DSL and Builder

Use DSL for the main flow, Builder for complex parts:

```elixir
defmodule MyApp.HybridTransaction do
  use MultiFlow.DSL, repo: MyApp.Repo
  import MultiFlow.Builders
  
  transaction "Hybrid approach" do
    # Use DSL for simple steps
    step :validate, :run do
      function &validate/2
    end
    
    step :create_record, :insert do
      schema Record
      builder &build/1
    end
  end
  
  # Override execute to add Builder steps
  def execute(params) do
    # Start with DSL steps
    base_multi = super(params)
    
    # Add Builder steps for complex logic
    base_multi
    |> conditional_step(params.complex?, :complex_step, &handle_complex/2)
    |> MyApp.Repo.transaction()
  end
end
```

## Best Practices

1. **Use DSL for**: Standard CRUD, clear linear flows
2. **Use Builder for**: Conditional logic, dynamic composition
3. **Combine both**: DSL for structure, Builder for flexibility
4. **Keep steps small**: Each step should do one thing
5. **Name steps clearly**: Use descriptive names
6. **Handle errors**: Use `on_error :continue` for optional steps
7. **Add descriptions**: Document what each step does

## Performance Tips

1. **Batch operations**: Use `insert_all` instead of multiple `insert`
2. **Update in bulk**: Use `update_all` instead of multiple `update`
3. **Avoid N+1**: Preload associations before the transaction
4. **Set timeouts**: For long-running transactions
5. **Use indexes**: Ensure proper database indexes

## Testing

```elixir
defmodule MyTransactionTest do
  use MyApp.DataCase
  
  test "creates user successfully" do
    params = %{email: "test@example.com", name: "Test"}
    
    assert {:ok, result} = MyApp.CreateUser.execute(params)
    assert result.create_user.email == "test@example.com"
    assert result.create_profile.user_id == result.create_user.id
  end
  
  test "handles validation errors" do
    params = %{email: nil, name: "Test"}
    
    assert {:error, :validate, "Email is required", _} = MyApp.CreateUser.execute(params)
  end
end
```

