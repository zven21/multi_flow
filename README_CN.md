# MultiFlow 🌌

[![Hex.pm](https://img.shields.io/hexpm/v/multi_flow.svg)](https://hex.pm/packages/multi_flow)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/multi_flow)
[![License](https://img.shields.io/hexpm/l/multi_flow.svg)](LICENSE)

**Language / 语言**: [English](README.md) | [中文](README_CN.md)

> 优雅的 DSL 和函数式构建器，用于 Ecto.Multi 事务处理

MultiFlow 让你用优雅的方式编写 Ecto.Multi 事务，支持 **DSL 宏**和**函数式 Builder** 两种风格。

## ✨ 特性

- 🎨 **优雅的 DSL** - 清晰表达业务逻辑
- 🔧 **函数式 Builder** - 灵活组合复杂事务
- ✅ **编译时验证** - 类型安全，错误提前发现
- 📝 **自文档化** - 代码即文档
- 🧪 **易于测试** - 每个步骤可独立测试
- 🔄 **可组合** - 复用事务片段
- 🎣 **Hooks 支持** - 横切关注点处理（before/after/error hooks）

## 📦 安装

将 MultiFlow 添加到 `mix.exs`：

```elixir
def deps do
  [
    {:multi_flow, "~> 0.1.0"}
  ]
end
```

## 🚀 快速开始

### DSL 方式（推荐用于标准事务）

```elixir
defmodule MyApp.CreateOrder do
  use MultiFlow.DSL
  
  # 定义横切关注点的 hooks
  before_transaction &log_start/1
  after_transaction &log_success/2
  error_hook &log_error/2
  
  transaction "创建订单及关联数据" do
    # 步骤1: 验证
    step :validate, :run do
      function &validate_customer/2
    end
    
    # 步骤2: 创建订单
    step :create_order, :insert do
      schema MyApp.Sales.Order
      builder &build_order/1
    end
    
    # 步骤3: 创建订单明细
    step :create_items, :insert_all do
      schema MyApp.Sales.OrderItem
      builder &build_items/1
      depends_on :create_order
    end
    
    # 步骤4: 更新库存
    step :update_stock, :update_all do
      query &stock_query/1
      set &stock_changes/1
    end
  end
  
  # Hook 实现
  defp log_start(params) do
    Logger.info("事务开始", params: params)
  end
  
  defp log_success(params, result) do
    Logger.info("事务完成", params: params, result: result)
  end
  
  defp log_error(params, reason) do
    Logger.error("事务失败", params: params, reason: reason)
  end
  
  # 实现辅助函数
  defp validate_customer(_repo, %{params: params}) do
    # 验证逻辑
    {:ok, %{customer_valid: true}}
  end
  
  defp build_order(%{params: params}) do
    %MyApp.Sales.Order{
      customer_id: params.customer_id,
      total: calculate_total(params.items)
    }
  end
  
  defp build_items(%{create_order: order, params: params}) do
    Enum.map(params.items, fn item ->
      %{
        order_id: order.id,
        item_id: item.item_id,
        qty: item.qty,
        price: item.price
      }
    end)
  end
  
  defp stock_query(%{create_items: {_, items}}) do
    item_ids = Enum.map(items, & &1.item_id)
    from s in Stock, where: s.item_id in ^item_ids
  end
  
  defp stock_changes(_changes) do
    [set: [updated_at: DateTime.utc_now()]]
  end
  
  defp calculate_total(items) do
    Enum.reduce(items, Decimal.new(0), fn item, acc ->
      Decimal.add(acc, Decimal.mult(item.qty, item.price))
    end)
  end
end

# 使用
{:ok, result} = MyApp.CreateOrder.execute(%{
  customer_id: 123,
  items: [
    %{item_id: 1, qty: 10, price: Decimal.new("99.99")},
    %{item_id: 2, qty: 5, price: Decimal.new("199.99")}
  ]
})
```

### Builder 方式（推荐用于复杂事务）

```elixir
defmodule MyApp.ProcessComplexOrder do
  import MultiFlow.Builders
  import Ecto.Query
  alias Ecto.Multi
  alias MyApp.Repo
  
  def execute(params) do
    Multi.new()
    |> add_validation_steps(params)
    |> add_order_creation(params)
    |> maybe_apply_discount(params)      # 条件步骤
    |> maybe_use_points(params)          # 条件步骤
    |> add_inventory_updates(params)
    |> add_payment_processing(params)
    |> add_notifications(params)
    |> Repo.transaction(timeout: 30_000)
  end
  
  # 可复用的步骤
  defp add_validation_steps(multi, params) do
    multi
    |> run_step(:validate_customer, fn _ ->
      validate_customer(params)
    end)
    |> run_step(:check_inventory, fn changes ->
      check_inventory(params, changes)
    end)
  end
  
  # 条件步骤
  defp maybe_apply_discount(multi, %{coupon: coupon}) when not is_nil(coupon) do
    run_step(multi, :apply_discount, fn changes ->
      apply_coupon(changes.create_order, coupon)
    end)
  end
  defp maybe_apply_discount(multi, _params), do: multi
  
  # 更多灵活的逻辑...
end
```

## 📚 核心概念

### DSL 宏

MultiFlow 提供了直观的 DSL 来定义事务：

```elixir
transaction "事务描述" do
  step :step_name, :step_type do
    # 配置
  end
end
```

**支持的步骤类型**:
- `:run` - 执行自定义函数
- `:insert` - 插入单条记录
- `:insert_all` - 批量插入
- `:update` - 更新单条记录
- `:update_all` - 批量更新
- `:delete` - 删除单条记录
- `:delete_all` - 批量删除

### Hooks 支持

MultiFlow DSL 支持横切关注点的 hooks：

```elixir
# 定义 hooks
before_transaction &log_start/1
after_transaction &log_success/2
error_hook &log_error/2

# Hook 函数签名
defp log_start(params) -> any()
defp log_success(params, result) -> any()
defp log_error(params, reason) -> any()
```

### Builder 工具

提供一系列函数式构建器，让你像搭积木一样组合事务：

```elixir
import MultiFlow.Builders

Multi.new()
|> run_step(:name, function)
|> insert_step(:name, schema, builder)
|> update_all_step(:name, query, set)
|> conditional_step(condition?, :name, function)
```

## 📖 文档

- [快速开始](guides/getting_started.md)
- [DSL 完整指南](guides/dsl_guide.md)
- [Builder 完整指南](guides/builder_guide.md)
- [真实案例](guides/real_world_examples.md)

## 🎯 适用场景

### 使用 DSL 的场景

✅ 标准 CRUD 操作  
✅ 逻辑清晰的事务（4-10步）  
✅ 需要优雅代码  
✅ 团队协作（代码统一风格）  
✅ 需要横切关注点处理（hooks）

### 使用 Builder 的场景

✅ 复杂条件逻辑  
✅ 需要动态组合步骤  
✅ 大量复用的事务片段  
✅ 需要最大灵活性  
✅ 需要运行时决策

## 🆚 与传统方式对比

### 传统方式

```elixir
def create_order(params) do
  Multi.new()
  |> Multi.run(:validate, fn _, _ ->
    if params.customer_id do
      {:ok, %{valid: true}}
    else
      {:error, "invalid"}
    end
  end)
  |> Multi.insert(:order, fn _ ->
    %Order{customer_id: params.customer_id}
  end)
  |> Multi.run(:items, fn repo, %{order: order} ->
    # 冗长的代码...
  end)
  |> Repo.transaction()
end
```

### MultiFlow 方式

```elixir
defmodule CreateOrder do
  use MultiFlow.DSL
  
  transaction "创建订单" do
    step :validate, :run do
      function &validate/2
    end
    
    step :order, :insert do
      schema Order
      builder &build/1
    end
    
    step :items, :insert_all do
      schema OrderItem
      builder &build_items/1
    end
  end
end
```

**更清晰、更易维护、更易测试！**

## 🚀 高级特性

### 1. 步骤依赖管理

```elixir
step :create_items, :insert_all do
  schema OrderItem
  builder &build_items/1
  depends_on :create_order  # 明确依赖关系
end
```

### 2. 条件步骤执行

```elixir
# DSL 方式
step :send_email, :run do
  function &send_welcome_email/2
  on_error :continue  # 失败时继续执行
end

# Builder 方式
|> conditional_step(params.send_email?, :send_email, &send_email/2)
```

### 3. 错误处理策略

```elixir
step :risky_operation, :run do
  function &risky_function/2
  on_error :rollback  # 失败时回滚整个事务
  retry 3             # 重试 3 次
end
```

### 4. 异步步骤支持

```elixir
step :send_notification, :run do
  function &send_notification/2
  async true  # 异步执行，不阻塞事务
end
```

## 📊 性能优化

### 批量操作

```elixir
# 使用 insert_all 而不是多个 insert
step :create_items, :insert_all do
  schema OrderItem
  builder &build_items/1
end
```

### 查询优化

```elixir
# 使用 update_all 而不是多个 update
step :update_inventory, :update_all do
  query &inventory_query/1
  set &inventory_changes/1
end
```

## 🧪 测试支持

### 单元测试

```elixir
defmodule CreateOrderTest do
  use ExUnit.Case
  
  test "creates order successfully" do
    params = %{customer_id: 123, items: [...]}
    
    assert {:ok, result} = CreateOrder.execute(params)
    assert result.create_order.customer_id == 123
    assert length(result.create_items) == 2
  end
end
```

### 集成测试

```elixir
defmodule OrderIntegrationTest do
  use ExUnit.Case
  
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end
  
  test "full order creation workflow" do
    # 测试完整的工作流程
  end
end
```

## 💡 真实案例

### 案例 1: 电商订单处理（复杂业务）

> 完整代码见 [examples/sales_order_dsl.ex](examples/sales_order_dsl.ex) 和 [examples/sales_order_builder.ex](examples/sales_order_builder.ex)

这是一个真实的电商订单处理流程，包含：
- 订单创建和更新
- 库存管理
- 财务处理
- 发货管理
- 状态流转

**使用 DSL 方式**（支持 hooks）：

```elixir
defmodule SalesOrder.DSL do
  use MultiFlow.DSL
  
  # 定义 hooks
  before_transaction &log_transaction_start/1
  after_transaction &log_transaction_success/2
  error_hook &log_transaction_error/2
  
  transaction "创建销售订单" do
    step :validate_customer, :run do
      function &validate_customer_exists/2
    end
    
    step :create_order, :insert do
      schema Order
      builder &build_order/1
    end
    
    step :create_items, :insert_all do
      schema OrderItem
      builder &build_order_items/1
      depends_on :create_order
    end
    
    # 条件步骤
    step :create_payment, :insert do
      schema Payment
      builder &build_payment/1
      depends_on :create_order
    end
  end
end
```

**使用 Builder 方式**（复杂条件逻辑）:

```elixir
defmodule SalesOrder.Builder do
  import MultiFlow.Builders
  
  def create_order(params) do
    Multi.new()
    |> add_validation(params)
    |> add_order_creation(params)
    |> maybe_immediate_payment(params)    # 条件：立即支付
    |> maybe_immediate_delivery(params)   # 条件：立即发货
    |> update_inventory(params)
    |> conditional_step(params.send_sms?, :send_sms, &send_sms_notification/2)
    |> Repo.transaction()
  end
end
```

### 案例 2: 用户注册（简单流程）

**使用 DSL 方式**（简单清晰）:

```elixir
defmodule User.Register do
  use MultiFlow.DSL
  
  transaction "用户注册流程" do
    step :create_user, :insert do
      schema User
      builder &build_user/1
    end
    
    step :create_profile, :insert do
      schema UserProfile
      builder &build_profile/1
    end
    
    step :send_welcome_email, :run do
      function &send_email/2
      on_error :continue  # 发送失败不影响注册
    end
  end
end
```

## 🆚 与传统方式对比

### 传统方式

```elixir
def create_order(params) do
  Multi.new()
  |> Multi.run(:validate, fn _, _ ->
    if params.customer_id do
      {:ok, %{valid: true}}
    else
      {:error, "invalid"}
    end
  end)
  |> Multi.insert(:order, fn _ ->
    %Order{customer_id: params.customer_id}
  end)
  |> Multi.run(:items, fn repo, %{order: order} ->
    # 冗长的代码...
  end)
  |> Repo.transaction()
end
```

### MultiFlow 方式

```elixir
defmodule CreateOrder do
  use MultiFlow.DSL
  
  transaction "创建订单" do
    step :validate, :run do
      function &validate/2
    end
    
    step :order, :insert do
      schema Order
      builder &build/1
    end
    
    step :items, :insert_all do
      schema OrderItem
      builder &build_items/1
    end
  end
end
```

**更清晰、更易维护、更易测试！**

## 🤝 贡献

欢迎贡献！我们期待您参与构建更好的开源 ERP 系统。

### 贡献流程

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b my-new-feature`)
3. 提交更改 (`git commit -am 'Add some feature'`)
4. 推送到分支 (`git push origin my-new-feature`)
5. 创建 Pull Request

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE)