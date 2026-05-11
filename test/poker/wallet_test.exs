defmodule Poker.WalletTest do
  use Poker.DataCase

  alias Poker.Wallet

  describe "wallet creation on registration" do
    test "creates wallet with initial balance when player is activated", ctx do
      %{player: player, wallet: wallet} = ctx |> produce(player: [:active])

      assert player.confirmed_at
      assert wallet.balance == 25_000
      assert wallet.reserved == 0
      assert wallet.player_id == player.id
    end

    test "does not create wallet for pending player", ctx do
      %{player: player} = ctx |> produce(:player)

      refute player.confirmed_at
      assert {:error, :wallet_not_found} = Wallet.get_wallet(player.id)
    end

    test "succeeds on retry if wallet was already created", ctx do
      %{player: player} = ctx |> produce(:player)

      # Simulate previous failed attempt where wallet was created but confirmation failed
      :ok = Wallet.create_wallet(player.id, initial_balance: 10_000)

      {:ok, confirmed} = Poker.Accounts.confirm_user(player)

      assert confirmed.confirmed_at
      assert {:ok, wallet} = Wallet.get_wallet(player.id)
      assert wallet.balance == 10_000
    end
  end
end
