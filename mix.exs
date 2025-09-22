defmodule Comb.MixProject do
  use Mix.Project

  def project do
    [
      app: :comb,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
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
      extra_applications: [:logger, :telemetry]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry, "~> 1.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
