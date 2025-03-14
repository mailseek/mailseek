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

  pipeline :admin_auth do
    plug MailseekWeb.Plug.BasicAuth
  end

  scope "/", MailseekWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api/messages", MailseekWeb do
    pipe_through :api_authenticated

    get "/", MessageController, :index
    post "/delete", MessageController, :delete
    post "/unsubscribe", MessageController, :unsubscribe
    get "/:message_id", MessageController, :show
  end

  scope "/api/reports", MailseekWeb do
    pipe_through :api_authenticated

    get "/", ReportController, :index
  end

  scope "/api/users", MailseekWeb do
    pipe_through :api_authenticated

    get "/:user_id/categories/:category_id/settings", UserController, :get_category_settings
    post "/:user_id/categories/:category_id/settings", UserController, :save_category_settings
    get "/categories", UserController, :list_categories
    post "/categories", UserController, :create_category
    get "/connected_accounts", UserController, :connected_accounts
    post "/google", UserController, :create_user
    post "/google/connect", UserController, :connect
  end

  scope "/" do
    pipe_through [:browser, :admin_auth]

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
