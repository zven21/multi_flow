defmodule MultiFlow.DSL do
  @moduledoc """
  DSL for defining Ecto.Multi transactions.
  
  Provides an elegant macro-based DSL for defining database transactions
  in a clear, declarative way.
  
  ## Example
  
      defmodule CreateUser do
        use MultiFlow.DSL
        
        # Define hooks for cross-cutting concerns
        before_transaction &log_start/1
        after_transaction &log_success/2
        error_hook &log_error/2
        
        transaction "Create user and profile" do
          step :validate, :run do
            function &validate_email/2
          end
          
          step :create_user, :insert do
            schema User
            builder &build_user/1
          end
          
          step :create_profile, :insert do
            schema UserProfile
            builder &build_profile/1
          end
        end
        
        defp validate_email(_repo, %{params: params}) do
          if valid_email?(params.email) do
            {:ok, %{email_valid: true}}
          else
            {:error, "Invalid email"}
          end
        end
        
        defp build_user(%{params: params}) do
          %User{email: params.email, name: params.name}
        end
        
        defp build_profile(%{create_user: user, params: params}) do
          %UserProfile{user_id: user.id, bio: params.bio}
        end
        
        # Hook implementations
        defp log_start(params) do
          Logger.info("Transaction started", params: params)
        end
        
        defp log_success(params, result) do
          Logger.info("Transaction completed", params: params, result: result)
        end
        
        defp log_error(params, reason) do
          Logger.error("Transaction failed", params: params, reason: reason)
        end
      end
      
      # Execute the transaction
      {:ok, result} = CreateUser.execute(%{
        email: "user@example.com",
        name: "John Doe",
        bio: "Developer"
      })
  """

  @doc false
  defmacro __using__(opts) do
    quote do
      import MultiFlow.DSL
      import Ecto.Query
      alias Ecto.Multi
      
      Module.register_attribute(__MODULE__, :steps, accumulate: true)
      Module.register_attribute(__MODULE__, :transaction_opts, accumulate: false)
      Module.register_attribute(__MODULE__, :before_hooks, accumulate: true)
      Module.register_attribute(__MODULE__, :after_hooks, accumulate: true)
      Module.register_attribute(__MODULE__, :error_hooks, accumulate: true)
      
      @repo Keyword.get(unquote(opts), :repo, nil)
      
      @before_compile MultiFlow.DSL
    end
  end

  @doc """
  Defines a transaction with a description.
  
  ## Example
  
      transaction "Create order" do
        step :validate, :run do
          function &validate/2
        end
      end
  """
  defmacro transaction(description, do: block) do
    quote do
      @transaction_description unquote(description)
      unquote(block)
    end
  end

  @doc """
  Defines a step in the transaction.
  
  ## Step Types
  
  - `:run` - Run a custom function
  - `:insert` - Insert a single record
  - `:insert_all` - Bulk insert records
  - `:update` - Update a single record
  - `:update_all` - Bulk update records
  - `:delete` - Delete a single record
  - `:delete_all` - Bulk delete records
  
  ## Example
  
      step :create_user, :insert do
        schema User
        builder &build_user/1
      end
  """
  defmacro step(name, type, do: block) do
    quote do
      @current_step %{name: unquote(name), type: unquote(type)}
      unquote(block)
      @steps @current_step
    end
  end

  @doc "Sets the description for a step"
  defmacro description(text) do
    quote do
      @current_step Map.put(@current_step, :description, unquote(text))
    end
  end

  @doc "Sets the function for a :run step"
  defmacro function(func) do
    quote do
      @current_step Map.put(@current_step, :function, unquote(func))
    end
  end

  @doc "Sets the schema for insert/update steps"
  defmacro schema(schema_module) do
    quote do
      @current_step Map.put(@current_step, :schema, unquote(schema_module))
    end
  end

  @doc "Sets the builder function"
  defmacro builder(func) do
    quote do
      @current_step Map.put(@current_step, :builder, unquote(func))
    end
  end

  @doc "Sets the query function for update_all/delete_all"
  defmacro query(func) do
    quote do
      @current_step Map.put(@current_step, :query, unquote(func))
    end
  end

  @doc "Sets the fields to update"
  defmacro set(func) do
    quote do
      @current_step Map.put(@current_step, :set, unquote(func))
    end
  end

  @doc "Sets the number of retries"
  defmacro retry(times) do
    quote do
      @current_step Map.put(@current_step, :retry, unquote(times))
    end
  end

  @doc "Sets error handling strategy (:rollback | :continue)"
  defmacro on_error(strategy) do
    quote do
      @current_step Map.put(@current_step, :on_error, unquote(strategy))
    end
  end

  @doc "Marks step as async (won't block transaction)"
  defmacro async(value) do
    quote do
      @current_step Map.put(@current_step, :async, unquote(value))
    end
  end

  @doc "Sets step dependencies"
  defmacro depends_on(step_names) when is_list(step_names) do
    quote do
      @current_step Map.put(@current_step, :depends_on, unquote(step_names))
    end
  end
  
  defmacro depends_on(step_name) do
    quote do
      @current_step Map.put(@current_step, :depends_on, [unquote(step_name)])
    end
  end

  @doc "Adds a before transaction hook"
  defmacro before_transaction(func) do
    quote do
      @before_hooks unquote(func)
    end
  end

  @doc "Adds an after transaction hook"
  defmacro after_transaction(func) do
    quote do
      @after_hooks unquote(func)
    end
  end

  @doc "Adds an error hook"
  defmacro error_hook(func) do
    quote do
      @error_hooks unquote(func)
    end
  end

  @doc """
  Compiles the DSL into executable code.
  """
  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Execute the transaction.
      
      #{@transaction_description || "No description provided"}
      """
      def execute(params) do
        # Execute before hooks
        execute_before_hooks(params)
        
        steps = @steps |> Enum.reverse()
        
        multi = 
          Enum.reduce(steps, Ecto.Multi.new(), fn step, acc ->
            add_step_to_multi(acc, step, params)
          end)
        
        repo = case @repo do
          nil -> raise "Repository not configured. Set it with `use MultiFlow.DSL, repo: MyApp.Repo`"
          repo -> repo
        end
        
        case repo.transaction(multi, get_transaction_opts()) do
          {:ok, result} ->
            # Execute after hooks on success
            execute_after_hooks(params, result)
            {:ok, result}
            
          {:error, reason} = error ->
            # Execute error hooks on failure
            execute_error_hooks(params, reason)
            error
        end
      end
      
      # Add a step to the Multi based on its type
      defp add_step_to_multi(multi, %{name: name, type: :run, function: func}, _params) do
        Ecto.Multi.run(multi, name, func)
      end
      
      defp add_step_to_multi(multi, %{name: name, type: :insert, builder: builder}, _params) do
        Ecto.Multi.insert(multi, name, fn changes ->
          builder.(changes)
        end)
      end
      
      defp add_step_to_multi(multi, %{name: name, type: :insert_all, schema: schema, builder: builder}, _params) do
        Ecto.Multi.run(multi, name, fn repo, changes ->
          records = builder.(changes)
          {count, inserted} = repo.insert_all(schema, records, returning: true)
          {:ok, {count, inserted}}
        end)
      end
      
      defp add_step_to_multi(multi, %{name: name, type: :update, builder: builder}, _params) do
        Ecto.Multi.update(multi, name, fn changes ->
          builder.(changes)
        end)
      end
      
      defp add_step_to_multi(multi, %{name: name, type: :update_all, query: query_fn, set: set_fn}, _params) do
        Ecto.Multi.update_all(multi, name, query_fn, set_fn)
      end
      
      defp add_step_to_multi(multi, %{name: name, type: :delete}, _params) do
        Ecto.Multi.delete(multi, name, fn changes ->
          # Assumes a :record key in changes
          changes[:record]
        end)
      end
      
      defp add_step_to_multi(multi, %{name: name, type: :delete_all, query: query_fn}, _params) do
        Ecto.Multi.delete_all(multi, name, fn changes ->
          query_fn.(changes)
        end)
      end
      
      
      defp get_transaction_opts do
        [timeout: 30_000]
      end
      
      # Execute before transaction hooks
      defp execute_before_hooks(params) do
        Enum.each(@before_hooks, fn hook ->
          hook.(params)
        end)
      end
      
      # Execute after transaction hooks
      defp execute_after_hooks(params, result) do
        Enum.each(@after_hooks, fn hook ->
          hook.(params, result)
        end)
      end
      
      # Execute error hooks
      defp execute_error_hooks(params, reason) do
        Enum.each(@error_hooks, fn hook ->
          hook.(params, reason)
        end)
      end
    end
  end
  
  @doc false
  def default_repo do
    case Application.get_env(:multi_verse, :repo) do
      nil -> 
        raise """
        Repository not configured. Please set it in config.exs:
        
            config :multi_verse, repo: MyApp.Repo
        
        Or when using the DSL:
        
            use MultiFlow.DSL, repo: MyApp.Repo
        """
      repo -> repo
    end
  end
end

