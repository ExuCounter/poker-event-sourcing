defmodule Poker.Wallet.Projectors.Wallet do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Wallet.Events.{
    WalletCreated,
    FundsDeposited,
    FundsReserved,
    FundsReleased,
    ReservationToppedUp,
    TopUpUndone
  }

  alias Poker.Wallet.Projections.Wallet

  project(%WalletCreated{player_id: player_id, balance: balance}, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :wallet, %Wallet{
      player_id: player_id,
      balance: balance,
      reserved: 0
    })
  end)

  project(%FundsDeposited{player_id: player_id, amount: amount}, _metadata, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :wallet,
      from(w in Wallet, where: w.player_id == ^player_id),
      inc: [balance: amount]
    )
  end)

  project(%FundsReserved{player_id: player_id, amount: amount}, _metadata, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :wallet,
      from(w in Wallet, where: w.player_id == ^player_id),
      inc: [balance: -amount, reserved: amount]
    )
  end)

  project(%ReservationToppedUp{player_id: player_id, amount: amount}, _metadata, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :wallet,
      from(w in Wallet, where: w.player_id == ^player_id),
      inc: [balance: -amount, reserved: amount]
    )
  end)

  project(%TopUpUndone{player_id: player_id, amount: amount}, _metadata, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :wallet,
      from(w in Wallet, where: w.player_id == ^player_id),
      inc: [balance: amount, reserved: -amount]
    )
  end)

  project(
    %FundsReleased{
      player_id: player_id,
      original_amount: original_amount,
      final_amount: final_amount
    },
    _metadata,
    fn multi ->
      Ecto.Multi.update_all(
        multi,
        :wallet,
        from(w in Wallet, where: w.player_id == ^player_id),
        inc: [reserved: -original_amount, balance: final_amount]
      )
    end
  )
end
