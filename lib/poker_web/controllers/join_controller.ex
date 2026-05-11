defmodule PokerWeb.JoinController do
  use PokerWeb, :controller

  alias Poker.Accounts
  alias PokerWeb.Api.JoinCodes
  alias PokerWeb.UserAuth

  def create(conn, %{"code" => code}) when is_binary(code) do
    case JoinCodes.resolve(code) do
      {:ok, path} -> redirect_to_game(conn, path)
      {:error, :not_found} -> redirect_with_error(conn, "Code not found. Check it and try again.")
    end
  end

  defp redirect_to_game(%{assigns: %{current_scope: %{user: %{}}}} = conn, path) do
    redirect(conn, to: path)
  end

  defp redirect_to_game(conn, path) do
    case Accounts.register_guest() do
      {:ok, user} ->
        conn
        |> put_session(:user_return_to, path)
        |> UserAuth.log_in_user(user)

      {:error, _reason} ->
        redirect_with_error(conn, "Couldn't start a guest session. Please try again.")
    end
  end

  defp redirect_with_error(conn, message) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: get_req_header(conn, "referer") |> List.first() || ~p"/users/log-in")
  end
end
