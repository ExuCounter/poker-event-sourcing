# Broadcastable protocol implementations for cash game events.
# See Poker.Events.Broadcastable for protocol definition.

for event_module <- [
      Poker.CashGames.Events.CashGameCreated,
      Poker.CashGames.Events.CashGameClosed
    ] do
  defimpl Poker.Events.Broadcastable, for: event_module do
    def for_broadcast(event), do: {:broadcast, Map.from_struct(event)}
  end
end
