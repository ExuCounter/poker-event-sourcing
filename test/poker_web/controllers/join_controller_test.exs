defmodule PokerWeb.JoinControllerTest do
  use PokerWeb.ConnCase

  alias Poker.Accounts.Schemas.User

  describe "POST /join" do
    test "redirects to the cash-game lobby for a valid code", ctx do
      %{cash_game: cash_game} =
        ctx
        |> produce(player: [:active])
        |> produce(:cash_game)

      conn = post(ctx.conn, ~p"/join", %{"code" => cash_game.code})

      assert redirected_to(conn) == ~p"/cash/#{cash_game.table_id}/lobby"
    end

    test "redirects to the tournament lobby for a valid code", ctx do
      %{tournament: tournament} =
        ctx
        |> produce(player: [:active])
        |> produce(:tournament)

      conn = post(ctx.conn, ~p"/join", %{"code" => tournament.code})

      assert redirected_to(conn) == ~p"/tournaments/#{tournament.id}/lobby"
    end

    test "auto-creates a guest session when no user is logged in", ctx do
      %{cash_game: cash_game} =
        ctx
        |> produce(player: [:active])
        |> produce(:cash_game)

      assert Poker.Repo.aggregate(User, :count, :id) == 1

      conn = post(ctx.conn, ~p"/join", %{"code" => cash_game.code})

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/cash/#{cash_game.table_id}/lobby"

      guest = Poker.Repo.get_by(User, is_guest: true)
      assert guest
    end

    test "flashes an error and redirects when the code is unknown", ctx do
      conn = post(ctx.conn, ~p"/join", %{"code" => "ZZZZZZZZ"})

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Code not found"
      assert redirected_to(conn)
    end
  end
end
