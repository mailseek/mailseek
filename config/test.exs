import Config
config :mailseek, Oban, testing: :manual

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :mailseek, Mailseek.Repo,
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("POSTGRES_HOSTNAME", "localhost"),
  database: "mailseek_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mailseek, MailseekWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Dz19ycNtD7yNcHOhVV9v9aMksAj191bCxIYoY5hYwAqEnQTKNY6DDiI+m0nmAMeq",
  server: false

# In test we don't send emails
config :mailseek, Mailseek.Mailer, adapter: Swoosh.Adapters.Test

# Default admin credentials for testing
config :mailseek, :admin_username, "admin"
config :mailseek, :admin_password, "admin"

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :mailseek, :gmail_client, Mailseek.MockGmailClient
config :mailseek, :token_manager, Mailseek.MockTokenManager
config :mailseek, :notifications, Mailseek.MockNotifications
config :mailseek, :users, Mailseek.MockUsers
config :mailseek, :gmail, Mailseek.MockGmail
config :mailseek, :llm, Mailseek.MockLLM
