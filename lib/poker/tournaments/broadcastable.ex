# Broadcastable protocol implementations for tournament events.
# See Poker.Events.Broadcastable for protocol definition.

# All tournament broadcasts are notification-only (no animation timing).
# LiveViews re-query tournament state on receipt.

for event_module <- [
      Poker.Tournaments.Events.TournamentCreated,
      Poker.Tournaments.Events.TournamentStarted,
      Poker.Tournaments.Events.TournamentFinished,
      Poker.Tournaments.Events.PlayerRegistered,
      Poker.Tournaments.Events.TournamentPlayerBusted,
      Poker.Tournaments.Events.BlindLevelAdvanced
    ] do
  defimpl Poker.Events.Broadcastable, for: event_module do
    def for_broadcast(event), do: {:broadcast, Map.from_struct(event)}
  end
end
