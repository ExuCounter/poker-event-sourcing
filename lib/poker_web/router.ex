defmodule PokerWeb.Router do
  use PokerWeb, :router

  import PokerWeb.PlayerAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PokerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_player
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PokerWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", PokerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:poker, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PokerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", PokerWeb do
    pipe_through [:browser, :require_authenticated_player]

    live_session :require_authenticated_player,
      on_mount: [{PokerWeb.PlayerAuth, :require_authenticated}] do
      live "/players/settings", PlayerLive.Settings, :edit
      live "/players/settings/confirm-email/:token", PlayerLive.Settings, :confirm_email
    end

    post "/players/update-password", PlayerSessionController, :update_password
  end

  scope "/", PokerWeb do
    pipe_through [:browser]

    live_session :current_player,
      on_mount: [{PokerWeb.PlayerAuth, :mount_current_scope}] do
      live "/players/register", PlayerLive.Registration, :new
      live "/players/log-in", PlayerLive.Login, :new
      live "/players/log-in/:token", PlayerLive.Confirmation, :new
    end

    post "/players/log-in", PlayerSessionController, :create
    delete "/players/log-out", PlayerSessionController, :delete
  end
end
