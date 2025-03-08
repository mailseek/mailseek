defmodule MailseekWeb.Router do
  use MailseekWeb, :router

  import Oban.Web.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MailseekWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug MailseekWeb.Plug.VerifyAuthenticated
  end

  scope "/", MailseekWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api/messages", MailseekWeb do
    pipe_through :api_authenticated

    get "/", MessageController, :index
    get "/:message_id", MessageController, :show
  end

  scope "/api/users", MailseekWeb do
    pipe_through :api_authenticated

    get "/categories", GmailController, :list_categories
    post "/categories", GmailController, :create_category
    get "/connected_accounts", GmailController, :connected_accounts
    post "/google", GmailController, :create_user
    post "/google/connect", GmailController, :connect
  end

  scope "/" do
    pipe_through :browser

    oban_dashboard("/oban")
  end

  # Other scopes may use custom stacks.
  # scope "/api", MailseekWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:mailseek, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MailseekWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
