defmodule Poker.Tables.Queries.HandEvents do
  @moduledoc """
  Queries for retrieving hand-specific events from EventStore.

  Provides functions to extract events for a specific hand by finding
  the HandStarted and HandFinished event boundaries.
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Events.{HandStarted, HandFinished}

  @doc """
  Get all events for a specific hand from EventStore.

  Returns events in order from HandStarted to HandFinished (inclusive).
  Returns empty list if hand is not found.

  ## Examples

      iex> events = Poker.Tables.Queries.HandEvents.get_hand_events("table-123", "hand-456")
      iex> is_list(events)
      true
  """
  def get_hand_events(table_id, hand_id) do
    stream_id = "table-#{table_id}"

    stream_id
    |> Poker.EventStore.stream_forward()
    |> Enum.to_list()
    |> find_hand_event_range(hand_id)
  end

  @doc """
  Get events for the previous hand (if exists).

  Builds the aggregate to get the prev_hand_id, then retrieves those events.

  ## Returns

    * `{:ok, events}` - List of events for the previous hand
    * `{:error, :no_previous_hand}` - No previous hand exists

  ## Examples

      iex> Poker.Tables.Queries.HandEvents.get_previous_hand_events("table-123")
      {:ok, [%{data: %HandStarted{}, ...}, ...]}

      iex> Poker.Tables.Queries.HandEvents.get_previous_hand_events("new-table")
      {:error, :no_previous_hand}
  """
  def get_previous_hand_events(table_id) do
    # First, build aggregate to get prev_hand_id
    aggregate = build_aggregate(table_id)

    case aggregate.prev_hand_id do
      nil -> {:error, :no_previous_hand}
      hand_id -> {:ok, get_hand_events(table_id, hand_id)}
    end
  end

  # Private helpers

  defp find_hand_event_range(events, hand_id) do
    # Find HandStarted event with matching id
    start_idx =
      Enum.find_index(events, fn event ->
        match?(%{data: %HandStarted{id: ^hand_id}}, event)
      end)

    if is_nil(start_idx) do
      []
    else
      # Find HandFinished event for this hand
      end_idx =
        events
        |> Enum.drop(start_idx)
        |> Enum.find_index(fn event ->
          match?(%{data: %HandFinished{hand_id: ^hand_id}}, event)
        end)

      if is_nil(end_idx) do
        []
      else
        # Adjust end_idx to be relative to full list
        actual_end_idx = start_idx + end_idx

        Enum.slice(events, start_idx..actual_end_idx)
      end
    end
  end

  defp build_aggregate(table_id) do
    "table-#{table_id}"
    |> Poker.EventStore.stream_forward()
    |> Enum.to_list()
    |> Enum.map(& &1.data)
    |> Enum.reduce(%Table{}, &Table.apply(&2, &1))
  end
end
