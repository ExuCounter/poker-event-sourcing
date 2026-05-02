defmodule Poker.CashGames.Events.CashGameClosed do
  @derive {Jason.Encoder, only: [:cash_game_id]}
  defstruct [:cash_game_id]
end
