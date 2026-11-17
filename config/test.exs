import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Database connection settings live in `config/runtime.exs` and are read
# from the `.env` file (shared with docker-compose) via Dotenvy.
# The test database is `blog_test` + optional MIX_TEST_PARTITION suffix.

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :blog, BlogWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "9MCc614DWbAcY+Ql4UaJiYHzdRjF36chJ4NBtb/09cptWAGJMpnEF21uPEFquC3K",
  server: false

# In test we don't send emails
config :blog, Blog.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
