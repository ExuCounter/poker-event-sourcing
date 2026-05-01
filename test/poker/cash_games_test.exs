defmodule Poker.CashGamesTest do
  use Poker.DataCase

  describe "join_cash_game/3 compensation" do
    test "releases reserved funds when join_participant fails", ctx do
      %{cash_game: cash_game, player: player, wallet: wallet} =
        ctx
        |> produce(player: [:active])
        |> produce(:cash_game)

      # join_participant will fail (seat_number validation), but reserve_funds succeeds first
      result = Poker.CashGames.join_cash_game(cash_game.id, player.id, cash_game.min_buyin)
      assert {:error, _reason} = result

      # Wallet should be restored — funds released after failed join
      {:ok, updated_wallet} = Poker.Wallet.get_wallet(player.id)
      assert updated_wallet.balance == wallet.balance
      assert updated_wallet.reserved == 0
    end

    test "does not reserve funds when validation fails", ctx do
      %{cash_game: cash_game, player: player, wallet: wallet} =
        ctx
        |> produce(player: [:active])
        |> produce(:cash_game)

      # buyin_too_low — should fail before reserve_funds
      result = Poker.CashGames.join_cash_game(cash_game.id, player.id, 1)
      assert {:error, :buyin_too_low} = result

      {:ok, updated_wallet} = Poker.Wallet.get_wallet(player.id)
      assert updated_wallet.balance == wallet.balance
      assert updated_wallet.reserved == 0
    end
  end
end
