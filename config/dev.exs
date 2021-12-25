use Mix.Config

# set to :debug to view SQL queries in logs
config :logger, level: :debug

config :quarry,
  ecto_repos: [Quarry.Repo]

config :quarry, Quarry.Repo,
  log: :debug,
  username: "postgres",
  password: "postgres",
  database: "quarry_dev",
  hostname: "localhost",
  pool_size: 10,
  priv: "test/support"
