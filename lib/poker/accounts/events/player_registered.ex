defmodule Poker.Accounts.Events.PlayerRegistered do
  @derive {Jason.Encoder, only: [:id, :email]}
  defstruct [:id, :email]
end
