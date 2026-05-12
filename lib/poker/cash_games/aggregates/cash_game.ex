defmodule Poker.CashGames.Aggregates.CashGame do
  @moduledoc """
  CashGame aggregate - manages cash game lifecycle.

  A cash game owns one table and defines the game settings.
  Players join/leave through the CashGames context which coordinates
  with Wallet (for funds) and Tables (for lobby).
  """

  alias Poker.CashGames.Commands.{
    CreateCashGame,
    CloseCashGame
  }

  alias Poker.CashGames.Events.{
    CashGameCreated,
    CashGameClosed
  }

  defstruct [
    :id,
    :table_id,
    :creator_id,
    :code,
    :status,
    :small_blind,
    :big_blind,
    :min_buyin,
    :max_buyin,
    :table_type
  ]

  # COMMAND HANDLERS

  def execute(%__MODULE__{id: nil}, %CreateCashGame{} = cmd) do
    %CashGameCreated{
      cash_game_id: cmd.cash_game_id,
      table_id: cmd.table_id,
      creator_id: cmd.creator_id,
      code: cmd.code,
      status: :active,
      small_blind: cmd.small_blind,
      big_blind: cmd.big_blind,
      min_buyin: cmd.min_buyin,
      max_buyin: cmd.max_buyin,
      table_type: cmd.table_type
    }
  end

  def execute(%__MODULE__{id: _existing}, %CreateCashGame{}) do
    {:error, :cash_game_already_exists}
  end

  def execute(%__MODULE__{id: nil}, _cmd) do
    {:error, :cash_game_not_found}
  end

  def execute(%__MODULE__{status: :closed}, %CloseCashGame{}) do
    {:error, :cash_game_already_closed}
  end

  def execute(%__MODULE__{}, %CloseCashGame{} = cmd) do
    %CashGameClosed{
      cash_game_id: cmd.cash_game_id
    }
  end

  # STATE MUTATORS

  def apply(%__MODULE__{}, %CashGameCreated{} = event) do
    %__MODULE__{
      id: event.cash_game_id,
      table_id: event.table_id,
      creator_id: event.creator_id,
      code: event.code,
      status: event.status,
      small_blind: event.small_blind,
      big_blind: event.big_blind,
      min_buyin: event.min_buyin,
      max_buyin: event.max_buyin,
      table_type: event.table_type
    }
  end

  def apply(%__MODULE__{} = state, %CashGameClosed{}) do
    %__MODULE__{state | status: :closed}
  end
end
