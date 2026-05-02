# Broadcastable protocol implementations for table events.
# See Poker.Events.Broadcastable for protocol definition.

# -- Broadcast with animation timing --

defimpl Poker.Events.Broadcastable, for: Poker.Tables.Events.HandStarted do
  def for_broadcast(event),
    do: {:broadcast, Map.from_struct(event), %{duration: 1000}}
end

defimpl Poker.Events.Broadcastable, for: Poker.Tables.Events.HandFinished do
  def for_broadcast(%{finish_reason: :all_folded} = event),
    do: {:broadcast, Map.from_struct(event), %{duration: 500}}

  def for_broadcast(event),
    do: {:broadcast, Map.from_struct(event), %{duration: 2000}}
end

defimpl Poker.Events.Broadcastable, for: Poker.Tables.Events.ParticipantHandGiven do
  def for_broadcast(event) do
    sanitized =
      event
      |> Map.from_struct()
      |> Map.delete(:hole_cards)

    {:broadcast, sanitized, %{duration: 700, stagger: 150}}
  end
end

defimpl Poker.Events.Broadcastable, for: Poker.Tables.Events.ParticipantShowdownCardsRevealed do
  def for_broadcast(event),
    do: {:broadcast, Map.from_struct(event), %{duration: 1100}}
end

defimpl Poker.Events.Broadcastable, for: Poker.Tables.Events.RoundStarted do
  def for_broadcast(event),
    do: {:broadcast, Map.from_struct(event), %{duration: 300, stagger: 150}}
end

for event_module <- [
      Poker.Tables.Events.ParticipantFolded,
      Poker.Tables.Events.ParticipantCalled,
      Poker.Tables.Events.ParticipantChecked,
      Poker.Tables.Events.ParticipantRaised,
      Poker.Tables.Events.ParticipantWentAllIn
    ] do
  defimpl Poker.Events.Broadcastable, for: event_module do
    def for_broadcast(event),
      do: {:broadcast, Map.from_struct(event), %{duration: 800}}
  end
end

for event_module <- [
      Poker.Tables.Events.SmallBlindPosted,
      Poker.Tables.Events.BigBlindPosted
    ] do
  defimpl Poker.Events.Broadcastable, for: event_module do
    def for_broadcast(event),
      do: {:broadcast, Map.from_struct(event), %{duration: 200}}
  end
end

defimpl Poker.Events.Broadcastable, for: Poker.Tables.Events.PotsRecalculated do
  def for_broadcast(event),
    do: {:broadcast, Map.from_struct(event), %{duration: 820}}
end

defimpl Poker.Events.Broadcastable, for: Poker.Tables.Events.PayoutDistributed do
  def for_broadcast(event),
    do: {:broadcast, Map.from_struct(event), %{duration: 2000}}
end

# -- Broadcast without animation (instant state update) --

for event_module <- [
      Poker.Tables.Events.ParticipantTimedOut,
      Poker.Tables.Events.ParticipantSatOut,
      Poker.Tables.Events.ParticipantSatIn,
      Poker.Tables.Events.ParticipantToActSelected,
      Poker.Tables.Events.DealerButtonMoved
    ] do
  defimpl Poker.Events.Broadcastable, for: event_module do
    def for_broadcast(event), do: {:broadcast, Map.from_struct(event)}
  end
end
