defmodule MultiFlow do
  @moduledoc """
  MultiFlow - Elegant DSL and functional builders for Ecto.Multi transactions.
  
  MultiFlow provides two powerful ways to work with Ecto.Multi:
  
  1. **DSL Macros** - For clear, declarative transaction definitions
  2. **Functional Builders** - For flexible, composable transaction steps
  
  ## Quick Example
  
  ### Using DSL
  
      defmodule CreateOrder do
        use MultiFlow.DSL
        
        transaction "Create order with items" do
          step :validate, :run do
            function &validate_customer/2
          end
          
          step :create_order, :insert do
            schema Order
            builder &build_order/1
          end
          
          step :create_items, :insert_all do
            schema OrderItem
            builder &build_items/1
          end
        end
        
        defp validate_customer(_repo, %{params: params}) do
          {:ok, %{customer_valid: true}}
        end
        
        defp build_order(%{params: params}) do
          %Order{customer_id: params.customer_id}
        end
        
        defp build_items(%{create_order: order, params: params}) do
          Enum.map(params.items, fn item ->
            %{order_id: order.id, item_id: item.id}
          end)
        end
      end
      
      # Execute
      {:ok, result} = CreateOrder.execute(%{customer_id: 1, items: [...]})
  
  ### Using Builders
  
      defmodule ProcessOrder do
        import MultiFlow.Builders
        alias Ecto.Multi
        
        def execute(params) do
          Multi.new()
          |> run_step(:validate, fn _ -> validate(params) end)
          |> insert_step(:order, Order, &build_order/1)
          |> conditional_step(params.use_coupon?, :discount, &apply_discount/2)
          |> MyApp.Repo.transaction()
        end
      end
  
  ## Installation
  
  Add to your `mix.exs`:
  
      def deps do
        [
          {:multi_verse, "~> 0.1.0"}
        ]
      end
  
  ## Documentation
  
  - [Getting Started Guide](guides/getting_started.md)
  - [DSL Guide](guides/dsl_guide.md)
  - [Builder Guide](guides/builder_guide.md)
  - [Real World Examples](guides/real_world_examples.md)
  """

  @doc """
  Returns the version of MultiFlow.
  """
  def version, do: Mix.Project.config()[:version]
end

