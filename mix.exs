defmodule Comb.MixProject do
  use Mix.Project

  @version "0.0.1"

  def project do
    [
      app: :comb,
      version: @version,
      elixir: "~> 1.12",
      name: "Comb",
      deps: deps(),
      dialyzer: [
        flags: [
          "-Wno_unknown",
          "-Werror_handling",
          "-Wunderspecs",
          "-Wno_undefined_callbacks",
          "-Wmissing_return",
          "-Wno_opaque",
          "extra_return"
        ],
        remove_defaults: [:unknown]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Comb.Application, []},
      extra_applications: [:logger, :telemetry]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:telemetry, "~> 1.0"},
      {:stream_data, "~> 0.5", only: [:dev, :test]},
      {:propcheck, "~> 1.4", only: [:test, :dev]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:phoenix_pubsub, "~> 2.0"}
    ]
  end
end
