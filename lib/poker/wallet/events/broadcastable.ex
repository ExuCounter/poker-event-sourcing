# Broadcastable protocol implementations for wallet events.
# See Poker.Events.Broadcastable for protocol definition.

for event_module <- [
      Poker.Wallet.Events.WalletCreated,
      Poker.Wallet.Events.FundsDeposited,
      Poker.Wallet.Events.FundsReserved,
      Poker.Wallet.Events.FundsReleased,
      Poker.Wallet.Events.ReservationToppedUp,
      Poker.Wallet.Events.TopUpUndone
    ] do
  defimpl Poker.Events.Broadcastable, for: event_module do
    def for_broadcast(event), do: {:broadcast, Map.from_struct(event)}
  end
end
