defmodule Spandex.Mixfile do
  use Mix.Project

  def project do
    [app: :spandex,
     version: "1.0.0-rc.2",
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     name: "Spandex",
     docs: docs(),
     source_url: "https://github.com/zachdaniel/spandex",
     deps: deps()]
  end

  def application() do
    [
      extra_applications: [:logger],
      mod: {Spandex, []}
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
  defp elixirc_paths(_),     do: ["lib"]

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:confex, "2.0.0"},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:decorator, "~> 1.2.0"},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:httpoison, "~> 0.11.1"},
      {:inch_ex, "~> 0.5", only: [:dev, :test]},
      {:msgpax, "~> 1.1"},
      {:plug, "~> 1.0"}
    ]
  end
end
