defmodule Adns.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "Elixir DNS codec, concurrent UDP client/server, and pluggable resolvers (RFC 1035)."

  def project do
    [
      app: :adns,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: @description,
      package: package(),
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

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/pepethefrogger/adns"
      },
      files: ~w(lib mix.exs README.md LICENSE mix.lock .formatter.exs bench)
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry, "~> 1.3"}
    ]
  end
end
