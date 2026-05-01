defmodule Poker.Wallet.Events.TopUpUndone do
  @derive {Jason.Encoder, only: [:player_id, :game_id, :amount]}
  defstruct [:player_id, :game_id, :amount]
end
