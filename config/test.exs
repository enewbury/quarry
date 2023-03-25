import Config

# set to :debug to view SQL queries in logs
config :logger, level: :warn

config :quarry,
  ecto_repos: [Quarry.Repo]

config :quarry, Quarry.Repo,
  log: :debug,
  adapter: Ecto.Adapters.SQLite3,
  database: "#{Mix.env()}.db",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support"
