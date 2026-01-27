defmodule Poker.Tables.Views.ReplayEvents do
  @moduledoc """
  Defines which events have frontend animations and should be steppable in replay.

  This list matches the events handled in poker_canvas.js runAnimation() function.
  Only these events trigger visual animations and should be part of step controls.
  """

  alias Poker.Tables.Events

  # Events that trigger animations in poker_canvas.js (lines 74-131)
  # These are the only events users should step through in replay mode
  @animated_events [
    Events.ParticipantRaised,
    Events.RoundStarted,
    Events.ParticipantHandGiven,
    Events.ParticipantFolded,
    Events.ParticipantCalled,
    Events.ParticipantChecked,
    Events.SmallBlindPosted,
    Events.BigBlindPosted,
    Events.ParticipantWentAllIn,
    Events.PayoutDistributed,
    Events.ParticipantShowdownCardsRevealed,
    Events.PotsRecalculated
  ]

  @doc """
  Returns list of event types that have frontend animations.
  """
  def animated_event_types, do: @animated_events

  @doc """
  Checks if an event has a frontend animation.

  ## Examples

      iex> alias Poker.Tables.Events.ParticipantRaised
      iex> Poker.Tables.Views.ReplayEvents.animated?(%ParticipantRaised{})
      true

      iex> alias Poker.Tables.Events.ParticipantToActSelected
      iex> Poker.Tables.Views.ReplayEvents.animated?(%ParticipantToActSelected{})
      false
  """
  def animated?(%Events.RoundStarted{community_cards: []}), do: false

  def animated?(event) when is_struct(event) do
    event.__struct__ in @animated_events
  end

  @doc """
  Filters a list of events to only those with animations.

  Preserves event metadata (event_id, etc.) when events are wrapped.

  ## Examples

      iex> events = [
      ...>   %{data: %Poker.Tables.Events.ParticipantRaised{}, event_id: "123"},
      ...>   %{data: %Poker.Tables.Events.DealerButtonMoved{}, event_id: "456"},
      ...>   %{data: %Poker.Tables.Events.RoundStarted{}, event_id: "789"}
      ...> ]
      iex> filtered = Poker.Tables.Views.ReplayEvents.filter_animated(events)
      iex> length(filtered)
      2
  """
  def filter_animated(events) when is_list(events) do
    Enum.filter(events, fn
      %{data: event} -> animated?(event)
      event -> animated?(event)
    end)
  end

  @doc """
  Builds a list of steppable events for replay controls.

  Returns events with their positions in the full event stream and extracted event IDs.
  This is useful for step forward/backward navigation.

  ## Returns

  A list of maps with:
    * `:event` - The event (or wrapped event with data and metadata)
    * `:position` - Index in the original event list
    * `:event_id` - Extracted event ID for tracking

  ## Examples

      iex> events = [
      ...>   %{data: %Poker.Tables.Events.ParticipantRaised{}, event_id: "abc"},
      ...>   %{data: %Poker.Tables.Events.DealerButtonMoved{}, event_id: "def"},
      ...>   %{data: %Poker.Tables.Events.RoundStarted{}, event_id: "ghi"}
      ...> ]
      iex> step_events = Poker.Tables.Views.ReplayEvents.build_step_events(events)
      iex> length(step_events)
      2
      iex> hd(step_events).event_id
      "abc"
      iex> hd(step_events).position
      0
  """
  def build_step_events(events) when is_list(events) do
    events
    |> Enum.with_index()
    |> Enum.filter(fn {event, _idx} ->
      case event do
        %{data: data} -> animated?(data)
        _ -> animated?(event)
      end
    end)
    |> Enum.map(fn {event, idx} ->
      %{
        event: event,
        position: idx,
        stream_version: get_stream_version(event)
      }
    end)
  end

  # Private helpers

  defp get_stream_version(%{stream_version: version}), do: version
  defp get_stream_version(%{data: _, stream_version: version}), do: version
  defp get_stream_version(_), do: nil
end
