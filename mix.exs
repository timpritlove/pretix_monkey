defmodule PretixMonkey.MixProject do
  use Mix.Project

  def project do
    [
      app: :pretix_monkey,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: PretixMonkey]
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
      {:req, "~> 0.5.7"},
      {:jason, "~> 1.4.4"},
      {:csv, "~> 3.2.1"},
      {:nimble_csv, "~> 1.1"}
    ]
  end
end
