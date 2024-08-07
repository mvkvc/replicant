defmodule Platform.MixProject do
  use Mix.Project

  def project do
    [
      app: :platform,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      dialyzer: dialyzer(),
      docs: docs(),
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      mod: {Platform.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/project.plt"}
    ]
  end

  defp docs_extras() do
    [
      "README.md"
    ] ++
      Enum.map(
        [
          "tldr",
          "api",
          "worker",
          "integrity",
          "faq"
        ],
        &"docs/#{&1}.md"
      )
  end

  defp docs do
    [
      main: "readme",
      extras: docs_extras(),
      formatters: ["html"]
    ]
  end

  defp deps do
    [
      {:bloom, "~> 0.0.8"},
      {:contex, "~> 0.5.0"},
      {:remote_ip, "~> 1.1"},
      {:cachex, "~> 3.6"},
      {:amqp, "~> 3.2"},
      {:sentry, "~> 10.0"},
      {:hackney, "~> 1.19"},
      #
      {:bcrypt_elixir, "~> 3.0"},
      {:phoenix, "~> 1.7.10"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.1"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.2"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, ">= 0.0.0"},
      #
      {:flame_on, "~> 0.6.0", only: [:dev, :test]},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": [
        "tailwind default --minify",
        "esbuild default --minify",
        "phx.digest",
        "sentry.package_source_code"
      ],
      lint: [
        "format --check-formatted --no-exit",
        "credo --mute-exit-status",
        "sobelow",
        "dialyzer"
      ]
    ]
  end
end
