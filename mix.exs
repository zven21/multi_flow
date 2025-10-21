defmodule MultiFlow.MixProject do
  use Mix.Project

  @version "1.0.0"
  @source_url "https://github.com/zven21/multi_flow"

  def project do
    [
      app: :multi_flow,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      
      # Hex
      description: description(),
      package: package(),
      
      # Docs
      name: "MultiFlow",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end
  
  defp description do
    """
    Make Ecto.Multi flow like water 🌊. A DSL and Builder pattern wrapper for Ecto.Multi
    that makes database transactions elegant, readable, and maintainable.
    """
  end
  
  defp package do
    [
      name: "multi_flow",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end
  
  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/getting_started.md",
        "guides/dsl_guide.md",
        "guides/builder_guide.md",
        "guides/real_world_examples.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.10"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end
end
