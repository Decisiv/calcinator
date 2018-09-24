defmodule Calcinator.Mixfile do
  use Mix.Project

  # Functions

  def project do
    [
      aliases: aliases(),
      app: :calcinator,
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      docs: docs(),
      elixir: "~> 1.3",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.circle": :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.post": :test,
        credo: :test,
        dialyze: :test,
        docs: :test
      ],
      source_url: "https://github.com/C-S-D/calcinator",
      start_permanent: Mix.env() == :prod,
      test_coverage: [
        tool: ExCoveralls
      ],
      version: "5.1.1"
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application, do: application(Mix.env())

  ## Private Functions

  defp aliases do
    [
      compile: "compile --ignore-module-conflict --warnings-as-errors",
      test: ["calcinator.ecto.wait", "ecto.drop", "ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end

  defp application(:test) do
    [
      applications: applications(:test),
      mod: {Calcinator.Application, []}
    ]
  end

  defp application(env) do
    [applications: applications(env)]
  end

  defp applications(:test) do
    [:ecto, :ex_machina, :faker, :mix, :phoenix, :plug, :postgrex, :pryin | applications(:dev)]
  end

  defp applications(_), do: ~w(alembic ja_serializer logger)a

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      # JSONAPI document coding
      {:alembic, "~> 3.4"},
      # Static Analysis
      {:credo, "0.8.10", only: :test},
      # Type checking
      {:dialyze, "~> 0.2.1", only: :test},
      {
        :earmark,
        "~> 1.0",
        # Commit with @KronicDeth's pragdave/earmark#144 PR that fixes unclosed backquote stickiness
        commit: "103af39dd22d4199100f5d5dce6b3afd5959e03e",
        github: "pragdave/earmark",
        only: [:dev, :test],
        override: true
      },
      # Code coveragei
      {:excoveralls, "~> 0.7.2", only: :test},
      {:ex_doc, "~> 0.17.1", only: [:dev, :test]},
      # documentation coverage
      {:inch_ex, "~> 0.5.1", only: [:dev, :test]},
      # Calcinator.Resources.Ecto.Repo tests
      {:ex_machina, "~> 2.0", only: :test},
      # Fake data for tests, so we don't have to come up with our own sequences for ExMachina
      {:faker, "~> 0.9.0", only: :test},
      {:ja_serializer, ">= 0.11.2 and < 0.13.0"},
      # JUnit formatter, so that CircleCI can consume test output for CircleCI UI
      {:junit_formatter, "~> 2.0", only: :test},
      # Phoenix.Controller is used in Calcinator.Controller.Error
      {:phoenix, "~> 1.0", optional: true},
      # Testing PryIn instrumenter
      {:pryin, "~> 1.0", optional: true},
      # PostgreSQL DB access for Calcinator.Resources.Ecto.Repo.Repo used in tests
      {:postgrex, "~> 0.13.0", only: :test},
      # Pagination in Calcinator.Resources.Ecto.Repo
      {:scrivener_ecto, "~> 1.3.0", optional: true},
      # UUID for `errors` `0` `id` in `Calcinator.Controller.backing_store_error`
      {:uuid, "~> 1.1", optional: true}
    ]
  end

  defp description do
    """
    Process JSONAPI requests in transport and backing store neutral way.
    """
  end

  defp docs do
    [
      extras: ~w(CHANGELOG.md CODE_OF_CONDUCT.md CONTRIBUTING.md LICENSE.md README.md UPGRADING.md)
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp extras do
    [
      "CODE_OF_CONDUCT.md",
      "CONTRIBUTING.md",
      "LICENSE.md",
      "README.md",
      "UPGRADING.md"
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs" | extras()],
      licenses: ["Apache 2.0"],
      links: %{
        "Docs" => "https://hexdocs.pm/calcinator",
        "Github" => "https://github.com/C-S-D/calcinator"
      },
      maintainers: ["Luke Imhoff"]
    ]
  end
end
