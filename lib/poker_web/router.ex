defmodule PokerWeb.Router do
  use PokerWeb, :router

  import PokerWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PokerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
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
    pipe_through [:browser, :require_authenticated_user]

    live_session :onboarding,
      on_mount: [{PokerWeb.UserAuth, :require_authenticated}] do
      live "/onboarding", UserLive.Onboarding, :new
    end

    live_session :common,
      on_mount: [
        {PokerWeb.UserAuth, :require_authenticated},
        {PokerWeb.UserAuth, :require_onboarded}
      ] do
      live "/", PlayerLive.Dashboard, :render
      live "/cash", PlayerLive.Dashboard, :cash_games
      live "/cash/:id/lobby", PlayerLive.Lobby, :show
      live "/tournaments", PlayerLive.Dashboard, :tournaments
      live "/tournaments/:id/lobby", PlayerLive.TournamentLobby, :show
      live "/history", PlayerLive.HandHistory, :all
      live "/history/cash", PlayerLive.HandHistory, :cash
      live "/history/tournaments", PlayerLive.HandHistory, :tournaments
    end

    live_session :registered_only,
      on_mount: [
        {PokerWeb.UserAuth, :require_authenticated},
        {PokerWeb.UserAuth, :require_onboarded},
        {PokerWeb.UserAuth, :require_registered_user}
      ] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    live_session :table,
      on_mount: [
        {PokerWeb.UserAuth, :require_authenticated},
        {PokerWeb.UserAuth, :require_onboarded}
      ],
      root_layout: {PokerWeb.Layouts, :table} do
      live "/tables/:id/game", PlayerLive.Game, :play
      live "/tables/:id/replay", PlayerLive.Replay, :play
      live "/tables/:id/replay/:hand_id", PlayerLive.Replay, :play
    end

    post "/users/update-password", UserSessionController, :update_password

    live_session :guest_upgrade,
      on_mount: [{PokerWeb.UserAuth, :require_authenticated}] do
      live "/guests/save-account", UserLive.GuestUpgrade, :new
    end

    resources "/tables/participants", ParticipantController, only: [:create]
  end

  scope "/", PokerWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{PokerWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete

    post "/guests/sign-in", GuestSessionController, :create

    get "/auth/google/sign-in", OAuthController, :sign_in
    get "/auth/google/register", OAuthController, :register
    get "/auth/:provider", OAuthController, :request
    get "/auth/:provider/callback", OAuthController, :callback

    get "/", PageController, :home
  end
end
