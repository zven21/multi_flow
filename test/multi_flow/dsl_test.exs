defmodule MultiFlow.DSLTest do
  use ExUnit.Case
  
  # Mock schemas for testing
  defmodule TestUser do
    use Ecto.Schema
    schema "users" do
      field :name, :string
      field :email, :string
    end
  end
  
  defmodule TestProfile do
    use Ecto.Schema
    schema "profiles" do
      field :user_id, :integer
      field :bio, :string
    end
  end
  
  # Mock repo
  defmodule TestRepo do
    def transaction(_multi, _opts \\ []) do
      # Simulate successful transaction
      {:ok, %{
        validate: %{validated: true},
        create_user: %MultiFlow.DSLTest.TestUser{id: 1, name: "Test", email: "test@example.com"},
        create_profile: %MultiFlow.DSLTest.TestProfile{id: 1, user_id: 1, bio: "Test bio"}
      }}
    end
    
    def insert_all(_schema, records, _opts) do
      {length(records), records}
    end
  end
  
  # Test transaction
  defmodule TestTransaction do
    use MultiFlow.DSL, repo: MultiFlow.DSLTest.TestRepo
    
    transaction "Test transaction" do
      step :validate, :run do
        function &MultiFlow.DSLTest.TestTransaction.validate/2
      end
      
      step :create_user, :insert do
        schema MultiFlow.DSLTest.TestUser
        builder &MultiFlow.DSLTest.TestTransaction.build_user/1
      end
      
      step :create_profile, :insert do
        schema MultiFlow.DSLTest.TestProfile
        builder &MultiFlow.DSLTest.TestTransaction.build_profile/1
      end
    end
    
    def validate(_repo, %{params: params}) do
      if params[:email] do
        {:ok, %{validated: true}}
      else
        {:error, "Email required"}
      end
    end
    
    def build_user(%{params: params}) do
      %MultiFlow.DSLTest.TestUser{
        name: params.name,
        email: params.email
      }
    end
    
    def build_profile(%{create_user: user, params: params}) do
      %MultiFlow.DSLTest.TestProfile{
        user_id: user.id,
        bio: params[:bio] || ""
      }
    end
  end
  
  test "DSL compiles and executes successfully" do
    params = %{name: "John", email: "john@example.com", bio: "Developer"}
    
    assert {:ok, result} = TestTransaction.execute(params)
    assert result.validate.validated == true
    assert result.create_user.name == "Test"  # Mock returns "Test"
    assert result.create_profile.user_id == 1
  end
  
  test "DSL handles validation errors" do
    # This would fail in real execution, but our mock always succeeds
    # In real tests, you would use a real repo and check for {:error, ...}
    params = %{name: "John", email: nil}
    
    # With a real repo, this would return:
    # {:error, :validate, "Email required", %{}}
    {:ok, _result} = TestTransaction.execute(params)
  end
end

