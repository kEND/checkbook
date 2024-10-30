defmodule Checkbook.MixProject do
  use Mix.Project

  def project do
    [
      app: :checkbook,
      version: "0.0.1",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "Some Credo checks for clean elixir app code"
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", runtime: true},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "checkbook",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/kend/checkbook"}
    ]
  end
end
