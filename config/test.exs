use Mix.Config

config :calcinator, Calcinator.Endpoint,
  instrumenters: [PryIn.Instrumenter],
  secret_key_base: "WUUiQKAzwOqYmugHEp5mBtPC4AJ8I16tZTIbxT5ZvOpZNrIIUFek1lrHWOTMAHHk"

config :calcinator, Calcinator.Resources.Ecto.Repo.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "calcinator_test",
  hostname: System.get_env("DATABASE_HOST") || "localhost",
  loggers: [PryIn.EctoLogger, Ecto.LogEntry],
  password: System.get_env("DATABASE_PASSWORD") || "",
  pool: Ecto.Adapters.SQL.Sandbox,
  username: System.get_env("DATABASE_USERNAME") || "postgres"

config :calcinator,
  ecto_repos: [Calcinator.Resources.Ecto.Repo.Repo],
  instrumenters: [Calcinator.PryIn.Instrumenter]

# Print only warnings and errors during test
config :logger, level: :warn

# Add JSON:API to known mimes
config :mime, :types, %{
  "application/vnd.api+json" => ["json-api"]
}

config :phoenix, :format_encoders, "json-api": Poison

config :pryin,
  api: Calcinator.PryIn.Api.Test,
  env: :staging,
  otp_app: :calcinator
