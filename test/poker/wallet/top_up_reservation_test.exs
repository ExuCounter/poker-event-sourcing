defmodule Poker.Wallet.TopUpReservationTest do
  use Poker.DataCase

  alias Poker.Wallet

  describe "top_up_reservation/3" do
    test "adds amount to existing reservation", ctx do
      %{player: player} = ctx |> produce(player: [:active])

      game_id = UUIDv7.generate()
      :ok = Wallet.reserve_funds(player.id, game_id, 1000)
      :ok = Wallet.top_up_reservation(player.id, game_id, 500)

      {:ok, wallet} = Wallet.get_wallet(player.id)
      assert wallet.balance == 25_000 - 1000 - 500
      assert wallet.reserved == 1500
    end

    test "fails when reservation does not exist", ctx do
      %{player: player} = ctx |> produce(player: [:active])

      game_id = UUIDv7.generate()
      result = Wallet.top_up_reservation(player.id, game_id, 500)

      assert {:error, :reservation_not_found} = result
    end

    test "fails when balance is insufficient", ctx do
      %{player: player} = ctx |> produce(player: [:active])

      game_id = UUIDv7.generate()
      :ok = Wallet.reserve_funds(player.id, game_id, 24_000)
      result = Wallet.top_up_reservation(player.id, game_id, 2000)

      assert {:error, :insufficient_funds} = result
    end
  end

  describe "undo_top_up/3" do
    test "removes amount from existing reservation", ctx do
      %{player: player} = ctx |> produce(player: [:active])

      game_id = UUIDv7.generate()
      :ok = Wallet.reserve_funds(player.id, game_id, 1000)
      :ok = Wallet.top_up_reservation(player.id, game_id, 500)
      :ok = Wallet.undo_top_up(player.id, game_id, 500)

      {:ok, wallet} = Wallet.get_wallet(player.id)
      assert wallet.balance == 25_000 - 1000
      assert wallet.reserved == 1000
    end

    test "fails when reservation does not exist", ctx do
      %{player: player} = ctx |> produce(player: [:active])

      game_id = UUIDv7.generate()
      result = Wallet.undo_top_up(player.id, game_id, 500)

      assert {:error, :reservation_not_found} = result
    end
  end
end
