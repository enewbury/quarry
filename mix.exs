defmodule Quarry.MixProject do
  use Mix.Project

  def project do
    [
      app: :quarry,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Docs
      name: "Quarry",
      source_url: "https://github.com/enewbury/quarry",
      homepage_url: "https://github.com/enewbury/quarry",
      docs: [
        # The main page in the docs
        main: "Quarry",
        # logo: "path/to/logo.png",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.5"},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:ecto_sql, "~> 3.5", only: [:test, :dev]},
      {:postgrex, "~> 0.14", only: [:test, :dev]},
      {:ex_machina, "~> 2.3", only: [:test, :dev]}
    ]
  end

  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
