defmodule Poker.Events.Transformer do
  @moduledoc """
  Transforms raw events into a consistent map format.

  Adds:
  - type (derived from module name)
  - event_id (from metadata or struct field)
  - stream_version (from metadata, used as cursor for incremental updates)
  """

  @doc """
  Transforms pre-sanitized event data for broadcast.
  Uses the sanitized map as the base, but derives type from the original event struct.
  Optionally includes timing for animation.
  """
  def transform_sanitized(sanitized_data, original_event, metadata, timing \\ nil)

  def transform_sanitized(
        sanitized_data,
        original_event,
        %{event_id: event_id, stream_version: stream_version},
        timing
      )
      when is_struct(original_event) do
    result =
      sanitized_data
      |> Map.put(:type, derive_event_type(original_event))
      |> Map.put(:event_id, event_id)
      |> Map.put(:stream_version, stream_version)

    if timing, do: Map.put(result, :timing, timing), else: result
  end

  @doc """
  Transforms a raw event struct into a map with type metadata.

  Accepts events in different formats:
  - EventStore format: %{data: event, event_id: id, stream_version: version}
  - Commanded format: event with separate metadata map
  - Already transformed: map with type and event_id fields
  """
  def transform(%{data: event, event_id: event_id, stream_version: stream_version})
      when is_struct(event) do
    do_transform(event, event_id, stream_version)
  end

  def transform(event) when is_struct(event) and is_map_key(event, :event_id) do
    do_transform(event, Map.get(event, :event_id), Map.get(event, :stream_version))
  end

  def transform(event, %{event_id: event_id, stream_version: stream_version})
      when is_struct(event) do
    do_transform(event, event_id, stream_version)
  end

  defp do_transform(event, event_id, stream_version) do
    event
    |> Map.from_struct()
    |> Map.put(:type, derive_event_type(event))
    |> Map.put(:event_id, event_id)
    |> Map.put(:stream_version, stream_version)
  end

  @doc """
  Derives event type name from module.

  Takes the last part of the module name as the event type.

  ## Examples

      iex> derive_event_type(%Poker.Tables.Events.HandStarted{})
      "HandStarted"
  """
  def derive_event_type(event) when is_struct(event) do
    event.__struct__
    |> Module.split()
    |> List.last()
  end
end
