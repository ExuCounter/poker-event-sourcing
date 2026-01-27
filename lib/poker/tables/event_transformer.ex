defmodule Poker.Tables.EventTransformer do
  @moduledoc """
  Transforms raw events into frontend-ready format.

  This module provides a single source of truth for event transformation,
  used by both live mode (via TableEventBroadcaster) and replay mode
  (via HandReplay).

  Adds:
  - event_id (from metadata or struct field, for debugging/logging)
  - stream_version (from metadata, used as cursor for incremental updates)
  - type (derived from module name)
  - timing (animation duration from AnimationDelays)
  """

  alias PokerWeb.AnimationDelays

  @doc """
  Transforms a raw event into frontend format.

  Accepts events in different formats:
  - EventStore format: %{data: event, event_id: id, stream_version: version}
  - Commanded format: event with separate metadata map
  - Already transformed: event with event_id and stream_version fields

  ## Examples

      # From EventStore (wrapped event)
      iex> transform(%{data: %HandStarted{table_id: "123"}, event_id: "uuid-123", stream_version: 5})
      %{table_id: "123", type: "HandStarted", event_id: "uuid-123", stream_version: 5, timing: %{duration: 1000}}

      # From Commanded metadata
      iex> transform(%HandStarted{table_id: "123"}, %{event_id: "uuid-123", stream_version: 5})
      %{table_id: "123", type: "HandStarted", event_id: "uuid-123", stream_version: 5, timing: %{duration: 1000}}
  """
  def transform(%{data: event, event_id: event_id, stream_version: stream_version}) when is_struct(event) do
    do_transform(event, event_id, stream_version)
  end

  def transform(event, %{event_id: event_id, stream_version: stream_version}) when is_struct(event) do
    do_transform(event, event_id, stream_version)
  end

  def transform(event) when is_struct(event) and is_map_key(event, :event_id) do
    event_id = Map.get(event, :event_id)
    stream_version = Map.get(event, :stream_version)
    do_transform(event, event_id, stream_version)
  end

  # Already transformed
  def transform(event) when is_map(event) and is_map_key(event, :type) and is_map_key(event, :event_id) do
    event
  end

  defp do_transform(event, event_id, stream_version) do
    event_type = derive_event_type(event)

    event
    |> Map.from_struct()
    |> Map.put(:type, event_type)
    |> Map.put(:event_id, event_id)
    |> Map.put(:stream_version, stream_version)
    |> Map.put(:timing, %{
      duration: AnimationDelays.for_event(event)
    })
  end

  @doc """
  Derives event type name from module.

  Takes the last part of the module name as the event type.

  ## Examples

      iex> derive_event_type(%Poker.Tables.Events.HandStarted{})
      "HandStarted"

      iex> derive_event_type(%Poker.Tables.Events.ParticipantRaised{})
      "ParticipantRaised"
  """
  def derive_event_type(event) when is_struct(event) do
    event.__struct__
    |> Module.split()
    |> List.last()
  end
end
