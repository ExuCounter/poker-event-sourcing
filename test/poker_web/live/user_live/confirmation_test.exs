defmodule PokerWeb.UserLive.ConfirmationTest do
  use PokerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Poker.AccountsFixtures

  alias Poker.Accounts

  setup do
    %{unconfirmed_user: unconfirmed_user_fixture(), confirmed_user: user_fixture()}
  end

  describe "Confirm user" do
    test "renders confirmation page for unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/users/log-in/#{token}")
      assert html =~ "Confirm and Stay Logged In"
    end

    test "renders login page for confirmed user", %{conn: conn, confirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/users/log-in/#{token}")
      refute html =~ "Confirm my account"
      assert html =~ "Log in"
    end

    test "confirms the given token once", %{conn: conn, unconfirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"user" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "User confirmed successfully"

      assert Accounts.get_user!(user.id).confirmed_at
      # we are logged in now
      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      # log out, new conn - token should now be invalid
      conn = build_conn()

      # Using the same token again should redirect to login page
      {:ok, _lv, _html} =
        live(conn, ~p"/users/log-in/#{token}")
        |> follow_redirect(conn, ~p"/users/log-in")

      # The token should be consumed, so no login token should exist
      refute Accounts.get_user_by_magic_link_token(token)
    end

    test "logs confirmed user in without changing confirmed_at", %{
      conn: conn,
      confirmed_user: user
    } do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#login_form", %{"user" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Welcome back!"

      assert Accounts.get_user!(user.id).confirmed_at == user.confirmed_at

      # log out, new conn - token should now be invalid
      conn = build_conn()

      # Using the same token again should redirect to login page
      {:ok, _lv, _html} =
        live(conn, ~p"/users/log-in/#{token}")
        |> follow_redirect(conn, ~p"/users/log-in")

      # The token should be consumed
      refute Accounts.get_user_by_magic_link_token(token)
    end

    test "raises error for invalid token", %{conn: conn} do
      # Invalid token should redirect to login page
      {:ok, _lv, _html} =
        live(conn, ~p"/users/log-in/invalid-token")
        |> follow_redirect(conn, ~p"/users/log-in")

      # The invalid token should not create a valid session
      refute Accounts.get_user_by_magic_link_token("invalid-token")
    end
  end
end
