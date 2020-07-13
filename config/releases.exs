import Config

config :requestbox, RequestboxWeb.Endpoint,
  http: [port: {:system, "PORT"}],
  url: [scheme: "http", host: System.get_env("HOSTNAME"), port: 80],
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :requestbox, Requestbox.Repo,
  url: System.get_env("DATABASE_URL")
