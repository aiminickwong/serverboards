defmodule Serverboards.Mixfile do
  use Mix.Project

  def project do
    [app: :serverboards,
     version: "0.6.159-gd6f98",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     name: "Serverboards",
     homepage_url: "https://serverboards.io",
     docs: [
       logo: "docs/serverboards.png",
       extras: ["README.md"]
     ]
  ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      applications:       [
            :logger,
            :ecto,
            :postgrex,
            :comeonin,
            :mom,
            :timex,
            :yaml_elixir,
            :cowboy, :ranch,
            :eventsourcing,
            :uuid,
            :eini,
            :logger_journald_backend,
            :quantum
            ],
      mod: {Serverboards, []},
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:myapp, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:mom, "~> 0.4"},
      {:ejournald, git: "git://github.com/serverboards/ejournald", override: true},
      {:logger_journald_backend, git: "git://github.com/xerions/logger_journald_backend"},
      {:eventsourcing, in_umbrella: true},
      {:ecto, "~> 2.1"},
      {:postgrex, "~> 0.13"},
      {:comeonin, "~> 2.5"},
      {:timex, "~> 2.1.4"},
      {:poison,  "~> 3.1"},
      {:yaml_elixir, "~> 1.0.0" },
      {:yamerl, github: "yakaz/yamerl" },
      {:cowboy, "~> 1.0"},
      {:exrm, ">= 1.0.8"},
      {:uuid, "~> 1.1" },
      {:eini, "~> 1.2"},
      {:quantum, ">= 1.8.1"},
    ]
  end
end
