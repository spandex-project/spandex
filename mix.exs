defmodule Spandex.Mixfile do
  use Mix.Project

  def project do
    [
      app: :spandex,
      version: "2.0.0",
      elixir: "~> 1.3",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      name: "Spandex",
      docs: docs(),
      source_url: "https://github.com/zachdaniel/spandex",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        "coveralls.travis": :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      deps: deps()
    ]
  end

  defp description do
    """
    A platform agnostic tracing library. Contributors welcome.
    """
  end

  defp package do
    # These are the default files included in the package
    [
      name: :spandex,
      maintainers: ["Zachary Daniel", "Andrew Summers"],
      licenses: ["MIT License"],
      links: %{"GitHub" => "https://github.com/zachdaniel/spandex"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md"
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:benchee, "~> 0.13.2", only: [:dev, :test]},
      {:credo, "~> 0.9.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:excoveralls, "~> 0.6", only: :test},
      {:inch_ex, "~> 0.5", only: [:dev, :test]},
      {:optimal, "~> 0.3.3"},
      {:plug, ">= 1.0.0"}
    ]
  end
end
