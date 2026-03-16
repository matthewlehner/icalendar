defmodule ICalendar.Mixfile do
  use Mix.Project

  @source_url "https://github.com/lpil/icalendar"
  @version "1.1.3"

  def project do
    [
      app: :icalendar,
      name: "ICalendar",
      version: @version,
      elixir: "~> 1.11",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp deps do
    [
      {:tz, "~> 0.26", optional: true},
      {:mix_test_watch, ">= 0.0.0", only: :dev},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      description: "An ICalendar file generator",
      maintainers: ["Louis Pilfold"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://hexdocs.pm/icalendar/changelog.html",
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md",
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
