# Getting Started with MultiFlow

## Installation

Add MultiFlow to your `mix.exs`:

```elixir
def deps do
  [
    {:multi_flow, "~> 0.1.0"}
  ]
end
```

Run `mix deps.get` to fetch the dependency.

## Configuration

Configure your repository (optional, can also pass it directly):

```elixir
# config/config.exs
config :multi_flow,
  repo: MyApp.Repo
```

## Your First Transaction

Let's create a simple user registration transaction:

```elixir
defmodule MyApp.CreateUser do
  use MultiFlow.DSL, repo: MyApp.Repo
  
  transaction "Create user with profile" do
    # Step 1: Validate input
    step :validate, :run do
      function &validate_params/2
    end
    
    # Step 2: Create user
    step :create_user, :insert do
      schema MyApp.Accounts.User
      builder &build_user/1
    end
    
    # Step 3: Create profile
    step :create_profile, :insert do
      schema MyApp.Accounts.Profile
      builder &build_profile/1
    end
    
    # Step 4: Send welcome email (optional, won't rollback on failure)
    step :send_email, :run do
      function &send_welcome_email/2
      on_error :continue
    end
  end
  
  # Implement the helper functions
  defp validate_params(_repo, %{params: params}) do
    cond do
      is_nil(params[:email]) -> {:error, "Email is required"}
      is_nil(params[:name]) -> {:error, "Name is required"}
      true -> {:ok, %{validated: true}}
    end
  end
  
  defp build_user(%{params: params}) do
    %MyApp.Accounts.User{
      email: params.email,
      name: params.name,
      password_hash: hash_password(params.password)
    }
  end
  
  defp build_profile(%{create_user: user, params: params}) do
    %MyApp.Accounts.Profile{
      user_id: user.id,
      bio: params[:bio] || ""
    }
  end
  
  defp send_welcome_email(_repo, %{create_user: user}) do
    # Send email logic
    MyApp.Emails.send_welcome(user.email)
    {:ok, %{email_sent: true}}
  end
  
  defp hash_password(password) do
    Bcrypt.hash_pwd_salt(password)
  end
end
```

## Execute the Transaction

```elixir
params = %{
  email: "user@example.com",
  name: "John Doe",
  password: "secret",
  bio: "Elixir developer"
}

case MyApp.CreateUser.execute(params) do
  {:ok, result} ->
    IO.puts("User created: #{result.create_user.id}")
    
  {:error, failed_operation, failed_value, _changes_so_far} ->
    IO.puts("Failed at #{failed_operation}: #{inspect(failed_value)}")
end
```

## Next Steps

- [Learn about DSL features](dsl_guide.md)
- [Learn about Builders](builder_guide.md)
- [See real-world examples](real_world_examples.md)

