defmodule Quarry.MixProject do
  use Mix.Project

  @version "0.2.1"
  @source_url "https://github.com/enewbury/quarry"

  def project do
    [
      app: :quarry,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Docs
      name: "Quarry",
      description: "A data-driven Ecto Query builder for nested associations.",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      docs: docs()
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
      {:ecto_sql, "~> 3.5", only: [:test]},
      {:postgrex, "~> 0.14", only: [:test]},
      {:ex_machina, "~> 2.3", only: [:test]}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package() do
    [
      maintainers: ["Eric Newbury"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs() do
    [
      main: "readme",
      name: "Quarry",
      logo: "logo.svg",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/quarry",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end
end
