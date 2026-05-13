defmodule Poker.Wallet.Aggregates.Wallet do
  @moduledoc """
  Wallet aggregate for managing player funds.

  Uses a Reserve/Release pattern:
  - `balance` - Available funds the player can use
  - `reservations` - Map of game_id => amount for funds held in active games

  When a player joins a game:
  1. ReserveFunds checks balance and creates a reservation
  2. Funds move from `balance` to `reservations`

  When a player leaves/wins:
  1. ReleaseFunds releases the reservation with final amount
  2. Final amount is added back to `balance`
  """

  alias Poker.Wallet.Commands.{
    CreateWallet,
    DepositFunds,
    ReserveFunds,
    ReleaseFunds,
    TopUpReservation,
    UndoTopUp
  }

  alias Poker.Wallet.Events.{
    WalletCreated,
    FundsDeposited,
    FundsReserved,
    FundsReleased,
    ReservationToppedUp,
    TopUpUndone
  }

  defstruct [
    :player_id,
    :balance,
    :reservations
  ]

  # COMMAND HANDLERS

  def execute(%__MODULE__{player_id: nil}, %CreateWallet{} = cmd) do
    %WalletCreated{
      player_id: cmd.player_id,
      balance: cmd.initial_balance
    }
  end

  def execute(%__MODULE__{player_id: _existing}, %CreateWallet{}) do
    {:error, :wallet_already_exists}
  end

  def execute(%__MODULE__{player_id: nil}, _cmd) do
    {:error, :wallet_not_found}
  end

  def execute(%__MODULE__{}, %DepositFunds{} = cmd) do
    %FundsDeposited{
      player_id: cmd.player_id,
      amount: cmd.amount
    }
  end

  def execute(%__MODULE__{balance: balance}, %ReserveFunds{amount: amount})
      when balance < amount do
    {:error, :insufficient_funds}
  end

  def execute(%__MODULE__{reservations: reservations}, %ReserveFunds{} = cmd) do
    if Map.has_key?(reservations, cmd.game_id) do
      {:error, :reservation_already_exists}
    else
      %FundsReserved{
        player_id: cmd.player_id,
        game_id: cmd.game_id,
        amount: cmd.amount
      }
    end
  end

  def execute(%__MODULE__{balance: balance}, %TopUpReservation{amount: amount})
      when balance < amount do
    {:error, :insufficient_funds}
  end

  def execute(%__MODULE__{reservations: reservations}, %TopUpReservation{} = cmd) do
    case Map.get(reservations, cmd.game_id) do
      nil ->
        {:error, :reservation_not_found}

      _existing ->
        %ReservationToppedUp{
          player_id: cmd.player_id,
          game_id: cmd.game_id,
          amount: cmd.amount
        }
    end
  end

  def execute(%__MODULE__{reservations: reservations}, %UndoTopUp{} = cmd) do
    case Map.get(reservations, cmd.game_id) do
      nil ->
        {:error, :reservation_not_found}

      _existing ->
        %TopUpUndone{
          player_id: cmd.player_id,
          game_id: cmd.game_id,
          amount: cmd.amount
        }
    end
  end

  def execute(%__MODULE__{reservations: reservations}, %ReleaseFunds{} = cmd) do
    case Map.get(reservations, cmd.game_id) do
      nil ->
        {:error, :reservation_not_found}

      original_amount ->
        %FundsReleased{
          player_id: cmd.player_id,
          game_id: cmd.game_id,
          original_amount: original_amount,
          final_amount: cmd.final_amount
        }
    end
  end

  # STATE MUTATORS

  def apply(%__MODULE__{}, %WalletCreated{} = event) do
    %__MODULE__{
      player_id: event.player_id,
      balance: event.balance,
      reservations: %{}
    }
  end

  def apply(%__MODULE__{balance: balance} = wallet, %FundsDeposited{amount: amount}) do
    %__MODULE__{wallet | balance: balance + amount}
  end

  def apply(
        %__MODULE__{balance: balance, reservations: reservations} = wallet,
        %FundsReserved{} = event
      ) do
    %__MODULE__{
      wallet
      | balance: balance - event.amount,
        reservations: Map.put(reservations, event.game_id, event.amount)
    }
  end

  def apply(
        %__MODULE__{balance: balance, reservations: reservations} = wallet,
        %ReservationToppedUp{} = event
      ) do
    %__MODULE__{
      wallet
      | balance: balance - event.amount,
        reservations: Map.update!(reservations, event.game_id, &(&1 + event.amount))
    }
  end

  def apply(
        %__MODULE__{balance: balance, reservations: reservations} = wallet,
        %TopUpUndone{} = event
      ) do
    %__MODULE__{
      wallet
      | balance: balance + event.amount,
        reservations: Map.update!(reservations, event.game_id, &(&1 - event.amount))
    }
  end

  def apply(
        %__MODULE__{balance: balance, reservations: reservations} = wallet,
        %FundsReleased{} = event
      ) do
    %__MODULE__{
      wallet
      | balance: balance + event.final_amount,
        reservations: Map.delete(reservations, event.game_id)
    }
  end
end
