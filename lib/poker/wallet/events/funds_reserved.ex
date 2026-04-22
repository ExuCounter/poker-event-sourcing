defmodule Poker.Wallet.Events.FundsReserved do
  @derive {Jason.Encoder, only: [:player_id, :game_id, :amount]}
  defstruct [:player_id, :game_id, :amount]
end
