use Mix.Config

# set to :debug to view SQL queries in logs
config :logger, level: :warn

config :quarry,
  ecto_repos: [Quarry.Repo]

config :quarry, Quarry.Repo,
  log: :debug,
  username: "postgres",
  password: "postgres",
  database: "quarry_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support"
