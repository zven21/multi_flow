defmodule MultiFlow.Builders do
  @moduledoc """
  Functional builders for composable Ecto.Multi transactions.
  
  Provides a set of helper functions to build Multi transactions
  in a functional, composable way.
  
  ## Example
  
      import MultiFlow.Builders
      alias Ecto.Multi
      
      def create_order(params) do
        Multi.new()
        |> run_step(:validate, fn _ -> validate(params) end)
        |> insert_step(:order, Order, &build_order/1)
        |> insert_all_step(:items, OrderItem, &build_items/1)
        |> conditional_step(params.send_email?, :email, &send_email/2)
        |> MyApp.Repo.transaction()
      end
  """

  alias Ecto.Multi

  @doc """
  Adds a :run step to the Multi.
  
  ## Example
  
      multi
      |> run_step(:validate, fn _changes ->
        {:ok, %{validated: true}}
      end)
  """
  @spec run_step(Multi.t(), atom(), function()) :: Multi.t()
  def run_step(multi, name, func) when is_function(func, 1) do
    Multi.run(multi, name, fn _repo, changes ->
      func.(changes)
    end)
  end
  
  def run_step(multi, name, func) when is_function(func, 2) do
    Multi.run(multi, name, func)
  end

  @doc """
  Adds an :insert step to the Multi.
  
  ## Example
  
      multi
      |> insert_step(:user, User, fn changes ->
        %User{name: changes.params.name}
      end)
  """
  @spec insert_step(Multi.t(), atom(), module(), function()) :: Multi.t()
  def insert_step(multi, name, _schema, builder) when is_function(builder, 1) do
    Multi.insert(multi, name, fn changes ->
      builder.(changes)
    end)
  end

  @doc """
  Adds an :insert_all step to the Multi.
  
  ## Example
  
      multi
      |> insert_all_step(:items, OrderItem, fn changes ->
        [%{order_id: changes.order.id, name: "Item 1"}]
      end)
  """
  @spec insert_all_step(Multi.t(), atom(), module(), function()) :: Multi.t()
  def insert_all_step(multi, name, schema, builder) when is_function(builder, 1) do
    Multi.run(multi, name, fn repo, changes ->
      records = builder.(changes)
      {count, inserted} = repo.insert_all(schema, records, returning: true)
      {:ok, {count, inserted}}
    end)
  end

  @doc """
  Adds an :update step to the Multi.
  
  ## Example
  
      multi
      |> update_step(:user, fn changes ->
        Ecto.Changeset.change(changes.user, %{updated: true})
      end)
  """
  @spec update_step(Multi.t(), atom(), function()) :: Multi.t()
  def update_step(multi, name, changeset_builder) when is_function(changeset_builder, 1) do
    Multi.update(multi, name, fn changes ->
      changeset_builder.(changes)
    end)
  end

  @doc """
  Adds an :update_all step to the Multi.
  
  ## Example
  
      multi
      |> update_all_step(:stock, 
        fn _ -> from(s in Stock, where: s.qty < 10) end,
        fn _ -> [set: [updated_at: DateTime.utc_now()]] end
      )
  """
  @spec update_all_step(Multi.t(), atom(), function(), function()) :: Multi.t()
  def update_all_step(multi, name, query_builder, set_builder) 
      when is_function(query_builder, 1) and is_function(set_builder, 1) do
    Multi.update_all(multi, name, query_builder, set_builder)
  end

  @doc """
  Adds a :delete step to the Multi.
  
  ## Example
  
      multi
      |> delete_step(:user, fn changes ->
        changes.user
      end)
  """
  @spec delete_step(Multi.t(), atom(), function()) :: Multi.t()
  def delete_step(multi, name, record_getter) when is_function(record_getter, 1) do
    Multi.delete(multi, name, fn changes ->
      record_getter.(changes)
    end)
  end

  @doc """
  Adds a :delete_all step to the Multi.
  
  ## Example
  
      multi
      |> delete_all_step(:old_records, fn changes ->
        from(r in Record, where: r.created_at < ^changes.cutoff_date)
      end)
  """
  @spec delete_all_step(Multi.t(), atom(), function()) :: Multi.t()
  def delete_all_step(multi, name, query_builder) when is_function(query_builder, 1) do
    Multi.delete_all(multi, name, fn changes ->
      query_builder.(changes)
    end)
  end

  @doc """
  Conditionally adds a step to the Multi.
  
  ## Example
  
      multi
      |> conditional_step(user.is_vip?, :vip_discount, fn changes ->
        {:ok, %{discount: 0.2}}
      end)
      
      # Only adds the step if user.is_vip? is true
  """
  @spec conditional_step(Multi.t(), boolean(), atom(), function()) :: Multi.t()
  def conditional_step(multi, condition, name, func) when is_boolean(condition) do
    if condition do
      run_step(multi, name, func)
    else
      multi
    end
  end

  @doc """
  Adds multiple steps from a list.
  
  ## Example
  
      steps = [
        {:validate, :run, &validate/2},
        {:create, :insert, {User, &build_user/1}}
      ]
      
      multi
      |> add_steps(steps)
  """
  @spec add_steps(Multi.t(), list()) :: Multi.t()
  def add_steps(multi, steps) when is_list(steps) do
    Enum.reduce(steps, multi, fn
      {name, :run, func}, acc ->
        run_step(acc, name, func)
        
      {name, :insert, {schema, builder}}, acc ->
        insert_step(acc, name, schema, builder)
        
      {name, :insert_all, {schema, builder}}, acc ->
        insert_all_step(acc, name, schema, builder)
        
      step, acc ->
        IO.warn("Unknown step format: #{inspect(step)}")
        acc
    end)
  end

  @doc """
  Wraps a step with retry logic.
  
  ## Example
  
      multi
      |> retry_step(:call_api, 3, 1000, fn changes ->
        call_external_api(changes)
      end)
  """
  @spec retry_step(Multi.t(), atom(), pos_integer(), pos_integer(), function()) :: Multi.t()
  def retry_step(multi, name, max_retries, delay_ms, func) 
      when is_function(func, 1) and max_retries > 0 do
    Multi.run(multi, name, fn _repo, changes ->
      do_retry(max_retries, delay_ms, fn -> func.(changes) end)
    end)
  end

  defp do_retry(0, _delay, _func), do: {:error, :max_retries_exceeded}
  
  defp do_retry(retries_left, delay, func) do
    case func.() do
      {:ok, result} -> 
        {:ok, result}
        
      {:error, _reason} when retries_left > 1 ->
        Process.sleep(delay)
        do_retry(retries_left - 1, delay, func)
        
      error ->
        error
    end
  end

  @doc """
  Merges another Multi into this one.
  
  Useful for composing reusable transaction fragments.
  
  ## Example
  
      defmodule CommonSteps do
        def validation_steps(params) do
          Multi.new()
          |> run_step(:validate_email, fn _ -> validate_email(params) end)
          |> run_step(:validate_phone, fn _ -> validate_phone(params) end)
        end
      end
      
      Multi.new()
      |> merge_multi(CommonSteps.validation_steps(params))
      |> insert_step(:user, User, &build_user/1)
  """
  @spec merge_multi(Multi.t(), Multi.t()) :: Multi.t()
  def merge_multi(multi, other_multi) do
    Multi.append(multi, other_multi)
  end

  @doc """
  Groups multiple steps into a named sub-transaction.
  
  ## Example
  
      multi
      |> group(:user_creation, fn multi ->
        multi
        |> insert_step(:user, User, &build_user/1)
        |> insert_step(:profile, Profile, &build_profile/1)
      end)
  """
  @spec group(Multi.t(), atom(), function()) :: Multi.t()
  def group(multi, name, builder_func) when is_function(builder_func, 1) do
    sub_multi = builder_func.(Multi.new())
    Multi.run(multi, name, fn repo, _changes ->
      case repo.transaction(sub_multi) do
        {:ok, results} -> {:ok, results}
        {:error, _op, reason, _changes} -> {:error, reason}
      end
    end)
  end

  @doc """
  Adds a step that always succeeds (for logging, metrics, etc).
  
  ## Example
  
      multi
      |> tap_step(:log_start, fn changes ->
        Logger.info("Transaction started")
        changes
      end)
  """
  @spec tap_step(Multi.t(), atom(), function()) :: Multi.t()
  def tap_step(multi, name, func) when is_function(func, 1) do
    Multi.run(multi, name, fn _repo, changes ->
      func.(changes)
      {:ok, changes}
    end)
  end

  @doc """
  Adds validation step with detailed error messages.
  
  ## Example
  
      multi
      |> validate_step(:check_params, fn changes ->
        cond do
          is_nil(changes.params.email) -> {:error, "Email required"}
          is_nil(changes.params.name) -> {:error, "Name required"}
          true -> :ok
        end
      end)
  """
  @spec validate_step(Multi.t(), atom(), function()) :: Multi.t()
  def validate_step(multi, name, validator) when is_function(validator, 1) do
    Multi.run(multi, name, fn _repo, changes ->
      case validator.(changes) do
        :ok -> {:ok, %{validated: true}}
        {:ok, result} -> {:ok, result}
        {:error, reason} -> {:error, reason}
      end
    end)
  end
end

