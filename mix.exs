defmodule Adns.MixProject do
  use Mix.Project

  def project do
    [
      app: :adns,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: extra_applications(Mix.env())
    ]
  end

  defp extra_applications(:dev), do: [:logger, :telemetry, :wx, :observer, :tools]
  defp extra_applications(_), do: [:logger]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry, "~> 1.3"}
    ]
  end
end
