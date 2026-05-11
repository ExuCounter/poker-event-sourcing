defmodule PokerWeb.UserLive.GuestUpgradeTest do
  use PokerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Poker.AccountsFixtures

  alias Poker.Accounts
  alias Poker.Accounts.Schemas.User

  describe "GET /guests/save-account" do
    test "redirects registered users to the dashboard", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/guests/save-account")
    end

    test "renders the upgrade form for guests", %{conn: conn} do
      {:ok, guest} = Accounts.register_guest()
      conn = log_in_user(conn, guest)

      {:ok, _lv, html} = live(conn, ~p"/guests/save-account")

      assert html =~ "SAVE ACCOUNT"
      assert html =~ "Save my account"
    end
  end

  describe "submit" do
    setup %{conn: conn} do
      {:ok, guest} = Accounts.register_guest()
      %{conn: log_in_user(conn, guest), guest: guest}
    end

    test "promotes the guest to a registered user with the same id", %{conn: conn, guest: guest} do
      {:ok, lv, _html} = live(conn, ~p"/guests/save-account")

      attrs = %{
        "email" => "convert@example.com",
        "password" => "longenoughsecret",
        "password_confirmation" => "longenoughsecret"
      }

      lv |> form("#guest_upgrade_form", user: attrs) |> render_submit()

      reloaded = Poker.Repo.get!(User, guest.id)
      refute reloaded.is_guest
      assert reloaded.email == "convert@example.com"
      assert reloaded.hashed_password
    end

    test "shows an error and stays on page when the email is taken", %{conn: conn} do
      _existing = user_fixture(%{email: "taken@example.com"})
      {:ok, lv, _html} = live(conn, ~p"/guests/save-account")

      attrs = %{
        "email" => "taken@example.com",
        "password" => "longenoughsecret",
        "password_confirmation" => "longenoughsecret"
      }

      html = lv |> form("#guest_upgrade_form", user: attrs) |> render_submit()

      assert html =~ "has already been taken"
    end
  end
end
