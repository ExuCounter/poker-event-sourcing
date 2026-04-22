defmodule Poker.Wallet.Events.WalletCreated do
  @derive {Jason.Encoder, only: [:player_id, :balance]}
  defstruct [:player_id, :balance]
end
