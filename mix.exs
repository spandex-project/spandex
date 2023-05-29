defmodule Spandex.Mixfile do
  use Mix.Project

  @source_url "https://github.com/spandex-project/spandex"
  @version "3.2.0"

  def project do
    [
      app: :spandex,
      version: @version,
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      name: "Spandex",
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.github": :test
      ],
      deps: deps(),
      dialyzer: [
        plt_local_path: "priv/plts",
        plt_core_path: "priv/plts"
      ]
    ]
  end

  defp description do
    """
    A platform agnostic tracing library. Contributors welcome.
    """
  end

  defp package do
    [
      name: :spandex,
      maintainers: ["Greg Mefford"],
      licenses: ["MIT License"],
      links: %{
        "GitHub" => @source_url,
        "Sponsor" => "https://github.com/sponsors/GregMefford"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: "static/spandex.png",
      source_url: @source_url,
      source_ref: @version,
      extras: ["CHANGELOG.md", "README.md"],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:benchee, "~> 1.0", only: [:dev, :test]},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:decorator, "~> 1.2", optional: true},
      {:optimal, "~> 0.3.3"},
      {:plug, "~> 1.0"}
    ]
  end
end
