defmodule Poker.CashGames.Events.CashGameClosed do
  @derive {Jason.Encoder, only: [:id]}
  defstruct [:id]
end
