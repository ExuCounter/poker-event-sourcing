defmodule PokerWeb.OAuthController do
  use PokerWeb, :controller

  plug Ueberauth

  alias Poker.Accounts
  alias PokerWeb.UserAuth

  def sign_in(conn, _params) do
    conn
    |> put_session(:oauth_intent, "sign_in")
    |> redirect(to: ~p"/auth/google")
  end

  def register(conn, _params) do
    conn
    |> put_session(:oauth_intent, "register")
    |> redirect(to: ~p"/auth/google")
  end

  def request(conn, _params), do: conn

  def callback(%{assigns: %{ueberauth_failure: _failure}} = conn, _params) do
    redirect_with_error(conn)
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    intent = get_session(conn, :oauth_intent)

    case authenticate(intent, auth) do
      {:ok, user} ->
        conn
        |> delete_session(:oauth_intent)
        |> UserAuth.log_in_user(user)

      :error ->
        redirect_with_error(conn)
    end
  end

  defp authenticate("sign_in", %Ueberauth.Auth{uid: uid}) do
    case Accounts.get_user_by_google_id(to_string(uid)) do
      nil -> :error
      user -> {:ok, user}
    end
  end

  defp authenticate("register", %Ueberauth.Auth{uid: uid, info: %{email: email}}) do
    case Accounts.register_with_google(%{google_id: to_string(uid), email: email}) do
      {:ok, user} -> {:ok, user}
      _ -> :error
    end
  end

  defp authenticate(_intent, _auth), do: :error

  defp redirect_with_error(conn) do
    intent = get_session(conn, :oauth_intent)

    redirect_to =
      case intent do
        "register" -> ~p"/users/register"
        _ -> ~p"/users/log-in"
      end

    conn
    |> delete_session(:oauth_intent)
    |> put_flash(:error, "Something went wrong.")
    |> redirect(to: redirect_to)
  end
end
