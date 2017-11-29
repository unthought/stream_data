defmodule StreamData.Mixfile do
  use Mix.Project

  @version "0.3.0"
  @repo_url "https://github.com/whatyouhide/stream_data"

  def project() do
    [
      app: :stream_data,
      version: @version,
      elixir: "~> 1.5",
      elixirc_paths: case Mix.env do
        :test -> ["lib", "test/support"]
        _     -> ["lib"]
      end,
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "StreamData",
      docs: [
        source_ref: "v#{@version}",
        main: "StreamData",
        source_url: @repo_url
      ],

      # Hex
      description: "Data generation and property-based testing for Elixir",
      package: [
        maintainers: ["Andrea Leopardi"],
        licenses: ["Apache 2.0"],
        links: %{"GitHub" => @repo_url}
      ]
    ]
  end

  def application() do
    [
      extra_applications: [:logger],
      env: [
        initial_size: 1,
        max_runs: 100,
        max_shrinking_steps: 100
      ]
    ]
  end
  
  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps() do
    [
      {:ex_doc, "~> 0.15", only: :dev}
    ]
  end
end
