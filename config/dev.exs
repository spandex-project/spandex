# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :git_ops,
  mix_project: Spandex.Mixfile,
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/spandex-project/spandex",
  types: [],
  # Instructs the tool to manage your mix version in your `mix.exs` file
  # See below for more information
  manage_mix_version?: true,
  # Instructs the tool to manage the version in your README.md
  # Pass in `true` to use `"README.md"` or a string to customize
  manage_readme_version: "README.md"
