defmodule PokerWeb.GuestSessionControllerTest do
  use PokerWeb.ConnCase

  import Poker.AccountsFixtures

  alias Poker.Accounts
  alias Poker.Accounts.Schemas.User
  alias Poker.Wallet

  describe "POST /guests/sign-in" do
    test "creates a guest user, seeds the wallet, and signs them in", %{conn: conn} do
      conn = post(conn, ~p"/guests/sign-in", %{})

      assert get_session(conn, :user_token)
      assert redirected_to(conn)

      [user] = Poker.Repo.all(User)
      assert user.is_guest
      assert {:ok, %{balance: 10_000}} = Wallet.get_wallet(user.id)
    end
  end

  describe "DELETE /users/log-out (guest)" do
    test "deletes the guest user record on logout", %{conn: conn} do
      {:ok, guest} = Accounts.register_guest()

      conn =
        conn
        |> log_in_user(guest)
        |> delete(~p"/users/log-out")

      assert redirected_to(conn) == ~p"/"
      refute Poker.Repo.get(User, guest.id)
    end

    test "keeps registered users intact on logout", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> delete(~p"/users/log-out")

      assert redirected_to(conn) == ~p"/"
      assert Poker.Repo.get(User, user.id)
    end
  end
end
