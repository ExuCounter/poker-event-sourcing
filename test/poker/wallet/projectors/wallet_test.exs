defmodule Poker.Wallet.Projectors.WalletTest do
  use Poker.DataCase

  alias Poker.Wallet.Projectors.Wallet, as: Projector
  alias Poker.Wallet.Projections.Wallet

  alias Poker.Wallet.Events.{
    WalletCreated,
    FundsDeposited,
    FundsReserved,
    FundsReleased
  }

  defp metadata do
    %{handler_name: "wallet_test", event_number: :erlang.unique_integer([:positive, :monotonic])}
  end

  defp create_wallet(player_id) do
    event = %WalletCreated{player_id: player_id, balance: 0}
    :ok = Projector.handle(event, metadata())
  end

  describe "WalletCreated event" do
    test "inserts wallet with balance and reserved=0" do
      player_id = Ecto.UUID.generate()

      :ok = Projector.handle(%WalletCreated{player_id: player_id, balance: 1000}, metadata())

      wallet = Repo.get(Wallet, player_id)

      assert wallet.player_id == player_id
      assert wallet.balance == 1000
      assert wallet.reserved == 0
    end
  end

  describe "FundsDeposited event" do
    test "increments balance" do
      player_id = Ecto.UUID.generate()
      create_wallet(player_id)

      :ok = Projector.handle(%FundsDeposited{player_id: player_id, amount: 500}, metadata())

      wallet = Repo.get(Wallet, player_id)

      assert wallet.balance == 500
    end

    test "increments balance multiple times" do
      player_id = Ecto.UUID.generate()
      create_wallet(player_id)

      :ok = Projector.handle(%FundsDeposited{player_id: player_id, amount: 500}, metadata())
      :ok = Projector.handle(%FundsDeposited{player_id: player_id, amount: 300}, metadata())

      wallet = Repo.get(Wallet, player_id)

      assert wallet.balance == 800
    end
  end

  describe "FundsReserved event" do
    test "decrements balance and increments reserved" do
      player_id = Ecto.UUID.generate()
      create_wallet(player_id)
      :ok = Projector.handle(%FundsDeposited{player_id: player_id, amount: 1000}, metadata())

      :ok =
        Projector.handle(
          %FundsReserved{player_id: player_id, game_id: Ecto.UUID.generate(), amount: 200},
          metadata()
        )

      wallet = Repo.get(Wallet, player_id)

      assert wallet.balance == 800
      assert wallet.reserved == 200
    end
  end

  describe "FundsReleased event" do
    test "decrements reserved by original_amount and increments balance by final_amount" do
      player_id = Ecto.UUID.generate()
      game_id = Ecto.UUID.generate()
      create_wallet(player_id)
      :ok = Projector.handle(%FundsDeposited{player_id: player_id, amount: 1000}, metadata())

      :ok =
        Projector.handle(
          %FundsReserved{player_id: player_id, game_id: game_id, amount: 200},
          metadata()
        )

      :ok =
        Projector.handle(
          %FundsReleased{
            player_id: player_id,
            game_id: game_id,
            original_amount: 200,
            final_amount: 350
          },
          metadata()
        )

      wallet = Repo.get(Wallet, player_id)

      assert wallet.balance == 1150
      assert wallet.reserved == 0
    end

    test "handles partial release when player lost chips" do
      player_id = Ecto.UUID.generate()
      game_id = Ecto.UUID.generate()
      create_wallet(player_id)
      :ok = Projector.handle(%FundsDeposited{player_id: player_id, amount: 1000}, metadata())

      :ok =
        Projector.handle(
          %FundsReserved{player_id: player_id, game_id: game_id, amount: 200},
          metadata()
        )

      :ok =
        Projector.handle(
          %FundsReleased{
            player_id: player_id,
            game_id: game_id,
            original_amount: 200,
            final_amount: 50
          },
          metadata()
        )

      wallet = Repo.get(Wallet, player_id)

      assert wallet.balance == 850
      assert wallet.reserved == 0
    end
  end
end
