defmodule PokerWeb.GuestSessionController do
  use PokerWeb, :controller

  alias Poker.Accounts
  alias PokerWeb.UserAuth

  def create(%{assigns: %{current_scope: %{user: %{}}}} = conn, _params) do
    # Already authenticated — reuse the existing session, never spawn another guest.
    redirect(conn, to: UserAuth.signed_in_path(conn))
  end

  def create(conn, _params) do
    case Accounts.register_guest() do
      {:ok, user} ->
        UserAuth.log_in_user(conn, user)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Couldn't start a guest session. Please try again.")
        |> redirect(to: ~p"/users/log-in")
    end
  end
end
