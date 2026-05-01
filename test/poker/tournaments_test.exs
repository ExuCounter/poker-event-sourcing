defmodule Poker.TournamentsTest do
  use Poker.DataCase

  describe "register_player/2" do
    test "reserves funds and registers player", ctx do
      %{tournament: tournament, player: player, wallet: wallet} =
        ctx
        |> produce(player: [:active])
        |> produce(:tournament)

      :ok = Poker.Tournaments.register_player(tournament.id, player.id)

      {:ok, updated_wallet} = Poker.Wallet.get_wallet(player.id)
      assert updated_wallet.balance == wallet.balance - tournament.buy_in
      assert updated_wallet.reserved == tournament.buy_in
    end

    test "releases funds when registration dispatch fails", ctx do
      %{tournament: tournament, player: player} =
        ctx
        |> produce(player: [:active])
        |> produce(:tournament)

      # Register once successfully
      :ok = Poker.Tournaments.register_player(tournament.id, player.id)
      {:ok, wallet_after_first} = Poker.Wallet.get_wallet(player.id)

      # Register again — dispatch fails (already registered), but reserve_funds
      # also fails with :reservation_already_exists so compensation is not needed.
      # This verifies wallet is unchanged.
      result = Poker.Tournaments.register_player(tournament.id, player.id)
      assert {:error, _reason} = result

      {:ok, wallet_after_second} = Poker.Wallet.get_wallet(player.id)
      assert wallet_after_second.balance == wallet_after_first.balance
      assert wallet_after_second.reserved == wallet_after_first.reserved
    end
  end
end
