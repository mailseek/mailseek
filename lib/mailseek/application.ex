defmodule Mailseek.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Oban.Telemetry.attach_default_logger()

    children = [
      MailseekWeb.Telemetry,
      Mailseek.Repo,
      {DNSCluster, query: Application.get_env(:mailseek, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:mailseek, Oban)},
      {Phoenix.PubSub, name: Mailseek.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Mailseek.Finch},
      Mailseek.Gmail.TokenManager,
      # Start a worker by calling: Mailseek.Worker.start_link(arg)
      # {Mailseek.Worker, arg},
      # Start to serve requests, typically the last entry
      MailseekWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mailseek.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MailseekWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
