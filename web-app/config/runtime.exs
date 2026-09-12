import Config

workspace = System.get_env("WORKSPACE")

if config_env() != :test and (is_nil(workspace) or String.trim(workspace) == "") do
  raise "WORKSPACE is required and must point to an accessible directory"
end

expand_path = fn
  "~" -> System.user_home!()
  "~/" <> path -> Path.join(System.user_home!(), path)
  path -> Path.expand(path)
end

matato_pi_config =
  System.get_env("MATATO_PI_CONFIG") ||
    if(config_env() == :test,
      do: Path.join(System.tmp_dir!(), "matato-pi-test"),
      else: Path.join(System.user_home!(), ".config/matato-pi")
    )

matato_pi_config = expand_path.(matato_pi_config)
File.mkdir_p!(matato_pi_config)
File.chmod!(matato_pi_config, 0o700)
database_path =
  Path.join(
    matato_pi_config,
    if(config_env() == :test, do: "matato-pi-test.sqlite3", else: "matato-pi.sqlite3")
  )

pi_session_dir =
  System.get_env("PI_CODING_AGENT_SESSION_DIR") ||
    Path.join([System.user_home!(), ".pi", "agent", "sessions"])

pi_session_dir = expand_path.(pi_session_dir)

config :web_app,
  workspace: workspace || System.tmp_dir!(),
  session_dir: pi_session_dir,
  automation_storage_path: matato_pi_config,
  database_path: database_path,
  pi_package_root: System.get_env("MATATO_PI_PACKAGE_ROOT") || Path.expand("../..", __DIR__)

config :web_app, WebApp.Repo,
  database: database_path,
  pool_size: 5,
  busy_timeout: 5_000,
  journal_mode: :wal,
  foreign_keys: :on

config :opentelemetry, :resource, service: [name: "matato-pi-web"]

if config_env() == :prod do
  otel_endpoint = System.get_env("OTEL_ENDPOINT", "http://localhost:4318") |> String.trim()

  case otel_endpoint do
    "" ->
      config :opentelemetry, traces_exporter: :none
      config :web_app, otel_endpoint: nil

    endpoint ->
      config :opentelemetry, traces_exporter: :otlp
      config :opentelemetry_exporter, otlp_protocol: :http_protobuf, otlp_endpoint: endpoint
      config :web_app, otel_endpoint: endpoint
  end
else
  config :opentelemetry, traces_exporter: :none
  config :web_app, otel_endpoint: nil
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/web_app start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :web_app, WebAppWeb.Endpoint, server: true
end

config :web_app, WebAppWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :web_app, WebAppWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
        # Gettext translations
        ~r"priv/gettext/.*\.po$",
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/web_app_web/router\.ex$",
        ~r"lib/web_app_web/(controllers|live|components)/.*\.(ex|heex)$"
      ]
    ]
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :web_app, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :web_app, WebAppWeb.Endpoint,
    url: [host: host, port: 4000, scheme: "https"],
    http: [
      # Bind to loopback. Put an authenticated TLS ingress in front for remote access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {127, 0, 0, 1}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :web_app, WebAppWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :web_app, WebAppWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :web_app, WebApp.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://swoosh.hexdocs.pm/Swoosh.html#module-installation for details.
end
