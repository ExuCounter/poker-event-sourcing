# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :poker, :scopes,
  user: [
    default: true,
    module: Poker.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Poker.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :poker,
  ecto_repos: [Poker.Repo],
  event_stores: [Poker.EventStore],
  generators: [timestamp_type: :utc_datetime]

config :poker, Poker.App,
  event_store: [
    adapter: Commanded.EventStore.Adapters.EventStore,
    event_store: Poker.EventStore
  ],
  pub_sub: :local,
  registry: :local

# Configures the endpoint
config :poker, PokerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PokerWeb.ErrorHTML, json: PokerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Poker.PubSub,
  live_view: [signing_salt: "1BXvS4EN"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :poker, Poker.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  poker: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  poker: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :poker, Poker.Services.Deck, dispatcher: Poker.Services.Deck.Implementation

config :poker, Poker.Services.HandEvaluator,
  dispatcher: Poker.Services.HandEvaluator.Implementation

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
