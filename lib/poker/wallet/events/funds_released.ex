defmodule Poker.Wallet.Events.FundsReleased do
  @derive {Jason.Encoder, only: [:player_id, :game_id, :original_amount, :final_amount]}
  defstruct [:player_id, :game_id, :original_amount, :final_amount]
end
