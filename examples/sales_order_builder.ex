defmodule MultiFlow.Examples.SalesOrderBuilder do
  @moduledoc """
  Sales Order Builder Version
  
  Uses MultiFlow.Builders functional builders to define sales order processing workflow.
  Demonstrates how to build complex database transactions in a functional way.
  
  ## Features
  
  - Functional composition, high flexibility
  - Conditional step support
  - Easy to test and debug
  - Can dynamically compose steps
  """

  import MultiFlow.Builders
  import Ecto.Query
  alias Ecto.Multi
  alias Decimal, as: D

  # ========== Main Entry Points ==========

  @doc """
  Create sales order (Builder version)
  
  ## Parameters
  
      %{
        customer_id: 123,
        warehouse_id: 1,
        items: [
          %{item_id: 1, qty: 10, price: D.new("99.99")},
          %{item_id: 2, qty: 5, price: D.new("199.99")}
        ],
        immediate_payment: true,      # Optional: immediate payment
        immediate_delivery: true,     # Optional: immediate delivery
        payment_method_id: 1,         # Payment method
        discount_amount: D.new("50")  # Optional: discount amount
      }
  """
  def create_order(params) do
    Multi.new()
    # Phase 1: Validation
    |> add_validation_phase(params)
    # Phase 2: Create core data
    |> add_creation_phase(params)
    # Phase 3: Calculate amounts
    |> add_calculation_phase(params)
    # Phase 4: Conditional steps (immediate payment/delivery)
    |> add_conditional_phase(params)
    # Phase 5: Update related data
    |> add_update_phase(params)
    # Phase 6: Notifications and logging
    |> add_notification_phase(params)
    |> execute_with_repo()
  end

  @doc """
  Add delivery to order
  """
  def add_delivery(params) do
    Multi.new()
    |> validate_step(:validate_order, fn _ ->
      validate_order_can_deliver(params.order_id)
    end)
    |> insert_step(:delivery, Delivery, fn changes ->
      build_delivery(params, changes)
    end)
    |> insert_all_step(:delivery_items, DeliveryItem, fn changes ->
      build_delivery_items(params, changes)
    end)
    |> update_all_step(:update_order_status, 
      &order_query/1,
      &calculate_delivery_status/1
    )
    |> update_all_step(:update_inventory,
      &inventory_query/1,
      &reduce_inventory/1
    )
    |> execute_with_repo()
  end

  @doc """
  Add payment record
  """
  def add_payment(params) do
    Multi.new()
    |> validate_step(:check_order, fn _ ->
      validate_order_can_pay(params.order_id)
    end)
    |> insert_step(:payment, Payment, fn changes ->
      build_payment(params, changes)
    end)
    |> update_all_step(:update_order,
      &order_query/1,
      &calculate_payment_status/1
    )
    |> execute_with_repo()
  end

  # ========== Phase 1: Validation ==========

  defp add_validation_phase(multi, params) do
    multi
    |> validate_step(:validate_customer, fn _ ->
      validate_customer_exists(params.customer_id)
    end)
    |> validate_step(:validate_items, fn _ ->
      validate_items_not_empty(params.items)
    end)
    |> run_step(:check_inventory, fn _ ->
      check_inventory_availability(params.items, params.warehouse_id)
    end)
  end

  defp validate_customer_exists(customer_id) do
    if customer_id do
      :ok
    else
      {:error, "Customer ID cannot be empty"}
    end
  end

  defp validate_items_not_empty(items) do
    if items && length(items) > 0 do
      :ok
    else
      {:error, "Order items cannot be empty"}
    end
  end

  defp check_inventory_availability(items, warehouse_id) do
    # Should actually query database to check inventory
    # Simplified to always succeed here
    {:ok, %{inventory_available: true}}
  end

  # ========== Phase 2: Create Core Data ==========

  defp add_creation_phase(multi, params) do
    multi
    |> insert_step(:create_order, Order, fn changes ->
      %Order{
        customer_id: params.customer_id,
        warehouse_id: params.warehouse_id,
        status: :draft,
        delivery_status: :not_delivered,
        billing_status: :not_billed,
        # Amounts calculated in subsequent steps
        total_amount: D.new(0),
        discount_amount: params[:discount_amount] || D.new(0)
      }
    end)
    |> insert_all_step(:create_items, OrderItem, fn changes ->
      order = changes.create_order
      
      Enum.map(params.items, fn item ->
        %{
          order_id: order.id,
          item_id: item.item_id,
          qty: item.qty,
          price: item.price,
          amount: D.mult(item.qty, item.price),
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      end)
    end)
  end

  # ========== Phase 3: Calculate Amounts ==========

  defp add_calculation_phase(multi, params) do
    multi
    |> run_step(:calculate_amounts, fn changes ->
      {_count, items} = changes.create_items
      
      total_amount = 
        Enum.reduce(items, D.new(0), fn item, acc ->
          D.add(acc, item.amount)
        end)
      
      discount = params[:discount_amount] || D.new(0)
      final_amount = D.sub(total_amount, discount)
      
      {:ok, %{
        total_amount: total_amount,
        discount_amount: discount,
        final_amount: final_amount
      }}
    end)
    |> update_step(:update_order_amounts, fn changes ->
      order = changes.create_order
      amounts = changes.calculate_amounts
      
      Ecto.Changeset.change(order, %{
        total_amount: amounts.total_amount,
        final_amount: amounts.final_amount,
        remaining_amount: amounts.final_amount
      })
    end)
  end

  # ========== Phase 4: Conditional Steps ==========

  defp add_conditional_phase(multi, params) do
    multi
    |> maybe_immediate_payment(params)
    |> maybe_immediate_delivery(params)
  end

  defp maybe_immediate_payment(multi, %{immediate_payment: true, payment_method_id: method_id} = params) do
    multi
    |> insert_step(:create_immediate_payment, Payment, fn changes ->
      order = changes.update_order_amounts
      
      %Payment{
        order_id: order.id,
        amount: order.final_amount,
        payment_method_id: method_id,
        payment_date: Date.utc_today(),
        status: :completed
      }
    end)
    |> update_step(:mark_order_paid, fn changes ->
      order = changes.update_order_amounts
      
      Ecto.Changeset.change(order, %{
        billing_status: :fully_billed,
        paid_amount: order.final_amount,
        remaining_amount: D.new(0)
      })
    end)
  end
  defp maybe_immediate_payment(multi, _params), do: multi

  defp maybe_immediate_delivery(multi, %{immediate_delivery: true} = params) do
    multi
    |> insert_step(:create_immediate_delivery, Delivery, fn changes ->
      order = Map.get(changes, :mark_order_paid, changes.update_order_amounts)
      
      %Delivery{
        order_id: order.id,
        warehouse_id: params.warehouse_id,
        delivery_date: Date.utc_today(),
        status: :completed
      }
    end)
    |> insert_all_step(:create_delivery_items, DeliveryItem, fn changes ->
      {_count, order_items} = changes.create_items
      delivery = changes.create_immediate_delivery
      
      Enum.map(order_items, fn item ->
        %{
          delivery_id: delivery.id,
          order_item_id: item.id,
          item_id: item.item_id,
          qty: item.qty,
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      end)
    end)
    |> update_step(:mark_order_delivered, fn changes ->
      order = Map.get(changes, :mark_order_paid, changes.update_order_amounts)
      
      Ecto.Changeset.change(order, %{
        delivery_status: :fully_delivered,
        status: :completed
      })
    end)
  end
  defp maybe_immediate_delivery(multi, _params), do: multi

  # ========== Phase 5: Update Related Data ==========

  defp add_update_phase(multi, params) do
    multi
    # Only update inventory if immediate delivery
    |> conditional_step(
      params[:immediate_delivery] == true,
      :update_inventory,
      fn changes ->
        update_inventory_for_delivery(changes)
      end
    )
    # Update customer statistics
    |> update_all_step(:update_customer_stats,
      &customer_query/1,
      fn changes ->
        [inc: [total_orders: 1, total_amount: get_latest_order(changes).final_amount]]
      end
    )
  end

  defp update_inventory_for_delivery(changes) do
    {_count, delivery_items} = changes.create_delivery_items
    
    # Should actually execute inventory deduction
    # Simplified return here
    {:ok, %{inventory_updated: true, items_count: length(delivery_items)}}
  end

  # ========== Phase 6: Notifications and Logging ==========

  defp add_notification_phase(multi, params) do
    multi
    |> tap_step(:log_transaction, fn changes ->
      order = get_latest_order(changes)
      IO.puts("📝 Order creation completed: ##{order.id}, Amount: #{order.final_amount}")
      changes
    end)
    |> conditional_step(params[:send_notification] != false, :send_notification, fn changes ->
      order = get_latest_order(changes)
      
      # Send notification asynchronously
      Task.start(fn ->
        send_order_notification(order)
      end)
      
      {:ok, %{notification_sent: true}}
    end)
  end

  # ========== Helper Functions ==========

  defp get_latest_order(changes) do
    # Find the latest order state based on conditional steps
    cond do
      Map.has_key?(changes, :mark_order_delivered) -> changes.mark_order_delivered
      Map.has_key?(changes, :mark_order_paid) -> changes.mark_order_paid
      Map.has_key?(changes, :update_order_amounts) -> changes.update_order_amounts
      true -> changes.create_order
    end
  end

  defp order_query(changes) do
    order = get_latest_order(changes)
    from o in Order, where: o.id == ^order.id
  end

  defp customer_query(changes) do
    order = get_latest_order(changes)
    from c in Customer, where: c.id == ^order.customer_id
  end

  defp inventory_query(changes) do
    {_count, items} = changes.create_delivery_items
    item_ids = Enum.map(items, & &1.item_id)
    
    from i in Inventory, 
      where: i.item_id in ^item_ids,
      where: i.warehouse_id == ^changes.create_immediate_delivery.warehouse_id
  end

  defp calculate_delivery_status(changes) do
    # Simplified: assume all items delivered
    [set: [delivery_status: :fully_delivered, updated_at: DateTime.utc_now()]]
  end

  defp calculate_payment_status(changes) do
    # Simplified: assume all paid
    [set: [billing_status: :fully_billed, updated_at: DateTime.utc_now()]]
  end

  defp reduce_inventory(changes) do
    {_count, items} = changes.create_delivery_items
    
    # Simplified to set timestamp, should actually reduce inventory quantity
    [set: [updated_at: DateTime.utc_now()]]
  end

  defp validate_order_can_deliver(order_id) do
    # Should actually query order status
    {:ok, %{can_deliver: true}}
  end

  defp validate_order_can_pay(order_id) do
    # Should actually query order status
    {:ok, %{can_pay: true}}
  end

  defp build_delivery(params, changes) do
    %Delivery{
      order_id: params.order_id,
      warehouse_id: params.warehouse_id,
      delivery_date: params[:delivery_date] || Date.utc_today()
    }
  end

  defp build_delivery_items(params, changes) do
    delivery = changes.delivery
    
    Enum.map(params.delivery_items, fn item ->
      %{
        delivery_id: delivery.id,
        item_id: item.item_id,
        qty: item.qty,
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    end)
  end

  defp build_payment(params, changes) do
    %Payment{
      order_id: params.order_id,
      amount: params.amount,
      payment_method_id: params.payment_method_id,
      payment_date: params[:payment_date] || Date.utc_today()
    }
  end

  defp send_order_notification(order) do
    IO.puts("📧 Sending order notification: Order ##{order.id}")
  end

  defp execute_with_repo do
    fn multi ->
      # Assume Repo is configured
      repo = Application.get_env(:multi_verse, :repo, DemoRepo)
      repo.transaction(multi, timeout: 60_000)
    end
  end

  # ========== Mock Schemas (for demo) ==========

  defmodule Order do
    use Ecto.Schema
    schema "orders" do
      field :customer_id, :integer
      field :warehouse_id, :integer
      field :status, :string
      field :delivery_status, :string
      field :billing_status, :string
      field :total_amount, :decimal
      field :discount_amount, :decimal
      field :final_amount, :decimal
      field :paid_amount, :decimal
      field :remaining_amount, :decimal
      timestamps()
    end
  end

  defmodule OrderItem do
    use Ecto.Schema
    schema "order_items" do
      field :order_id, :integer
      field :item_id, :integer
      field :qty, :integer
      field :price, :decimal
      field :amount, :decimal
      timestamps()
    end
  end

  defmodule Delivery do
    use Ecto.Schema
    schema "deliveries" do
      field :order_id, :integer
      field :warehouse_id, :integer
      field :delivery_date, :date
      field :status, :string
      timestamps()
    end
  end

  defmodule DeliveryItem do
    use Ecto.Schema
    schema "delivery_items" do
      field :delivery_id, :integer
      field :order_item_id, :integer
      field :item_id, :integer
      field :qty, :integer
      timestamps()
    end
  end

  defmodule Payment do
    use Ecto.Schema
    schema "payments" do
      field :order_id, :integer
      field :amount, :decimal
      field :payment_method_id, :integer
      field :payment_date, :date
      field :status, :string
      timestamps()
    end
  end

  defmodule Customer do
    use Ecto.Schema
    schema "customers" do
      field :name, :string
      field :total_orders, :integer
      field :total_amount, :decimal
      timestamps()
    end
  end

  defmodule Inventory do
    use Ecto.Schema
    schema "inventory" do
      field :item_id, :integer
      field :warehouse_id, :integer
      field :qty, :integer
      timestamps()
    end
  end

  defmodule DemoRepo do
    def transaction(multi, _opts) do
      # Mock execution, use real Repo in actual projects
      IO.puts("🔄 Executing sales order transaction (Builder version)...")
      {:ok, %{
        create_order: %Order{id: 1001},
        create_items: {2, []},
        calculate_amounts: %{total_amount: D.new("1999.85")}
      }}
    end
    
    def insert_all(schema, records, _opts) do
      {length(records), records}
    end
  end
end
