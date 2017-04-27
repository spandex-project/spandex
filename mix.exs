defmodule Spandex.Mixfile do
  use Mix.Project

  def project do
    [app: :spandex,
     version: "0.1.3",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     name: "Spandex",
     source_url: "https://github.com/albert-io/spandex",
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger],
     mod: {Spandex.Application, []}]
  end

  defp description do
    """
    A Datadog APM tracing library. Still young, under active development, but is under active use.
    Contributions welcome.
    """
  end

  defp package do
    # These are the default files included in the package
    [
      name: :spandex,
      maintainers: ["Zachary Daniel", "Andrew Summers"],
      licenses: ["MIT License"],
      links: %{"GitHub" => "https://github.com/albert-io/spandex"}
    ]
  end

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
      {:decorator, "~> 1.2.0"},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:httpoison, "~> 0.11.1"},
      {:msgpax, "~> 1.1"},
      {:plug, "~> 1.0"},
      {:poison, "~> 3.0"}
    ]
  end
end
