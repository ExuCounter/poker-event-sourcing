defmodule PokerWeb.UserSessionControllerTest do
  use PokerWeb.ConnCase, async: true

  alias Poker.Accounts

  describe "POST /users/log-in - email and password" do
    test "logs the user in", %{conn: conn} = ctx do
      dbg(ctx.conn)
      ctx = ctx |> produce(user: [:confirmed])
      ctx = ctx |> exec(:set_user_password, password: "valid_user_password")

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => ctx.user.email, "password" => "valid_user_password"}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ ctx.user.email
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log-out"
    end

    test "logs the user in with remember me", %{conn: conn} = ctx do
      ctx = ctx |> produce(user: [:confirmed])
      ctx = ctx |> exec(:set_user_password, password: "valid_user_password")

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{
            "email" => ctx.user.email,
            "password" => "valid_user_password",
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_poker_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with return to", %{conn: conn} = ctx do
      ctx = ctx |> produce(user: [:confirmed])
      ctx = ctx |> exec(:set_user_password, password: "valid_user_password")

      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/users/log-in", %{
          "user" => %{
            "email" => ctx.user.email,
            "password" => "valid_user_password"
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} = ctx do
      ctx = ctx |> produce(user: [:confirmed])

      conn =
        post(conn, ~p"/users/log-in?mode=password", %{
          "user" => %{"email" => ctx.user.email, "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "POST /users/log-in - magic link" do
    test "logs the user in", %{conn: conn} = ctx do
      ctx = ctx |> produce(user: [:confirmed])
      {token, _hashed_token} = generate_user_magic_link_token(ctx.user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => token}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ ctx.user.email
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log-out"
    end

    test "confirms unconfirmed user", %{conn: conn} = ctx do
      ctx = ctx |> produce(:user)
      {token, _hashed_token} = generate_user_magic_link_token(ctx.user)
      refute ctx.user.confirmed_at

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => token},
          "_action" => "confirmed"
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "User confirmed successfully."

      assert Accounts.get_user!(ctx.user.id).confirmed_at

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ ctx.user.email
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log-out"
    end

    test "redirects to login page when magic link is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => "invalid"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "The link is invalid or it has expired."

      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "DELETE /users/log-out" do
    test "logs the user out", %{conn: conn} = ctx do
      ctx = ctx |> produce(user: [:confirmed], conn: [:user_session])
      conn = conn |> delete(~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
