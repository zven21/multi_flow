defmodule MultiFlow.Examples.SalesOrderDSL do
  @moduledoc """
  Sales Order DSL Version
  
  Uses MultiFlow.DSL macros to define sales order processing workflow.
  Demonstrates how to define complex database transactions in a declarative way.
  
  ## Features
  
  - Declarative syntax, more readable
  - Clear step dependencies
  - Conditional step support
  - Automatic error handling
  """

  use MultiFlow.DSL, repo: MultiFlow.Examples.SalesOrderDSL.DemoRepo
  import Ecto.Query
  alias Decimal, as: D

  # Define hooks for cross-cutting concerns
  before_transaction &log_transaction_start/1
  after_transaction &log_transaction_success/2
  error_hook &log_transaction_error/2

  # ========== Main Entry Points ==========

  @doc """
  Create sales order (DSL version)
  
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
  transaction "Create sales order" do
    # Phase 1: Validation
    step :validate_customer, :run do
      description "Validate customer exists"
      function &validate_customer_exists/2
    end
    
    step :validate_items, :run do
      description "Validate order items"
      function &validate_items_not_empty/2
    end
    
    step :check_inventory, :run do
      description "Check inventory availability"
      function &check_inventory_availability/2
    end

    # Phase 2: Create core data
    step :create_order, :insert do
      description "Create order"
      schema Order
      builder &build_order/1
    end
    
    step :create_items, :insert_all do
      description "Create order items"
      schema OrderItem
      builder &build_order_items/1
      depends_on :create_order
    end

    # Phase 3: Calculate amounts
    step :calculate_amounts, :run do
      description "Calculate order amounts"
      function &calculate_order_amounts/2
      depends_on [:create_order, :create_items]
    end
    
    step :update_order_amounts, :update do
      description "Update order amounts"
      builder &update_order_with_amounts/1
      depends_on [:create_order, :calculate_amounts]
    end

    # Phase 4: Conditional steps (immediate payment)
    step :create_immediate_payment, :insert do
      description "Create immediate payment record"
      schema Payment
      builder &build_immediate_payment/1
      depends_on :update_order_amounts
    end
    
    step :mark_order_paid, :update do
      description "Mark order as paid"
      builder &mark_order_as_paid/1
      depends_on [:update_order_amounts, :create_immediate_payment]
    end

    # Phase 5: Conditional steps (immediate delivery)
    step :create_immediate_delivery, :insert do
      description "Create immediate delivery record"
      schema Delivery
      builder &build_immediate_delivery/1
      depends_on :update_order_amounts
    end
    
    step :create_delivery_items, :insert_all do
      description "Create delivery items"
      schema DeliveryItem
      builder &build_delivery_items/1
      depends_on [:create_items, :create_immediate_delivery]
    end
    
    step :mark_order_delivered, :update do
      description "Mark order as delivered"
      builder &mark_order_as_delivered/1
      depends_on [:update_order_amounts, :create_immediate_delivery]
    end

    # Phase 6: Update related data
    step :update_inventory, :run do
      description "Update inventory"
      function &update_inventory_for_delivery/2
      depends_on :create_delivery_items
    end
    
    step :update_customer_stats, :run do
      description "Update customer statistics"
      function &update_customer_statistics/2
      depends_on :update_order_amounts
    end

    # Phase 7: Notifications and logging
    step :log_transaction, :run do
      description "Log transaction"
      function &log_order_creation/2
      depends_on :update_order_amounts
    end
    
    step :send_notification, :run do
      description "Send notification"
      function &send_order_notification/2
      depends_on :update_order_amounts
    end
  end

  # ========== Hook Implementations ==========

  defp log_transaction_start(params) do
    IO.puts("🚀 Starting sales order transaction with params: #{inspect(params)}")
    Logger.info("Sales order transaction started", params: params)
  end

  defp log_transaction_success(params, result) do
    IO.puts("✅ Sales order transaction completed successfully")
    Logger.info("Sales order transaction completed", params: params, result: result)
    
    # Send metrics, notifications, etc.
    send_order_metrics(:success, params, result)
  end

  defp log_transaction_error(params, reason) do
    IO.puts("❌ Sales order transaction failed: #{inspect(reason)}")
    Logger.error("Sales order transaction failed", params: params, reason: reason)
    
    # Send alerts, metrics, etc.
    send_order_metrics(:error, params, reason)
    send_order_alert(reason)
  end

  defp send_order_metrics(status, params, result_or_reason) do
    # Simulate metrics sending
    IO.puts("📊 Sending order metrics: #{status}")
  end

  defp send_order_alert(reason) do
    # Simulate alert sending
    IO.puts("🚨 Sending order alert: #{reason}")
  end

  # ========== Validation Functions ==========

  defp validate_customer_exists(_repo, %{params: %{customer_id: customer_id}}) do
    if customer_id do
      {:ok, %{customer_valid: true}}
    else
      {:error, "Customer ID cannot be empty"}
    end
  end

  defp validate_items_not_empty(_repo, %{params: %{items: items}}) do
    if items && length(items) > 0 do
      {:ok, %{items_valid: true}}
    else
      {:error, "Order items cannot be empty"}
    end
  end

  defp check_inventory_availability(_repo, %{params: %{items: items, warehouse_id: warehouse_id}}) do
    # Should actually query database to check inventory
    # Simplified to always succeed here
    {:ok, %{inventory_available: true}}
  end

  # ========== Builder Functions ==========

  defp build_order(%{params: params}) do
    %Order{
      customer_id: params.customer_id,
      warehouse_id: params.warehouse_id,
      status: :draft,
      delivery_status: :not_delivered,
      billing_status: :not_billed,
      total_amount: D.new(0),
      discount_amount: params[:discount_amount] || D.new(0)
    }
  end

  defp build_order_items(%{create_order: order, params: %{items: items}}) do
    Enum.map(items, fn item ->
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
  end

  defp build_immediate_payment(%{params: %{immediate_payment: true, payment_method_id: method_id}, update_order_amounts: order}) do
    %Payment{
      order_id: order.id,
      amount: order.final_amount,
      payment_method_id: method_id,
      payment_date: Date.utc_today(),
      status: :completed
    }
  end

  defp build_immediate_delivery(%{params: %{immediate_delivery: true, warehouse_id: warehouse_id}, update_order_amounts: order}) do
    %Delivery{
      order_id: order.id,
      warehouse_id: warehouse_id,
      delivery_date: Date.utc_today(),
      status: :completed
    }
  end

  defp build_delivery_items(%{create_items: {_count, order_items}, create_immediate_delivery: delivery}) do
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
  end

  # ========== Calculation Functions ==========

  defp calculate_order_amounts(_repo, %{create_items: {_count, items}, params: params}) do
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
  end

  defp update_order_with_amounts(%{create_order: order, calculate_amounts: amounts}) do
    Ecto.Changeset.change(order, %{
      total_amount: amounts.total_amount,
      final_amount: amounts.final_amount,
      remaining_amount: amounts.final_amount
    })
  end

  defp mark_order_as_paid(%{update_order_amounts: order}) do
    Ecto.Changeset.change(order, %{
      billing_status: :fully_billed,
      paid_amount: order.final_amount,
      remaining_amount: D.new(0)
    })
  end

  defp mark_order_as_delivered(%{update_order_amounts: order}) do
    Ecto.Changeset.change(order, %{
      delivery_status: :fully_delivered,
      status: :completed
    })
  end

  # ========== Update Functions ==========

  defp update_inventory_for_delivery(_repo, %{create_delivery_items: {_count, delivery_items}}) do
    # Should actually execute inventory deduction
    # Simplified return here
    {:ok, %{inventory_updated: true, items_count: length(delivery_items)}}
  end

  defp update_customer_statistics(_repo, %{update_order_amounts: order}) do
    # Should actually update customer statistics
    {:ok, %{customer_stats_updated: true, order_amount: order.final_amount}}
  end

  # ========== Notification Functions ==========

  defp log_order_creation(_repo, %{update_order_amounts: order}) do
    IO.puts("📝 Order creation completed: ##{order.id}, Amount: #{order.final_amount}")
    {:ok, %{logged: true}}
  end

  defp send_order_notification(_repo, %{update_order_amounts: order}) do
    # Send notification asynchronously
    Task.start(fn ->
      IO.puts("📧 Sending order notification: Order ##{order.id}")
    end)
    
    {:ok, %{notification_sent: true}}
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
      IO.puts("🔄 Executing sales order transaction (DSL version)...")
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
