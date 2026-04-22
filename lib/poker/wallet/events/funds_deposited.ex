defmodule Poker.Wallet.Events.FundsDeposited do
  @derive {Jason.Encoder, only: [:player_id, :amount]}
  defstruct [:player_id, :amount]
end
