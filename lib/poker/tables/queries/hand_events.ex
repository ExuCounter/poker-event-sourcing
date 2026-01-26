defmodule Poker.Tables.Queries.HandEvents do
  @moduledoc """
  Queries for retrieving hand-specific events from EventStore.

  Uses the hand_histories projection for efficient event lookup.
  """

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
    case get_hand_history(table_id, hand_id) do
      nil ->
        {nil, []}

      hand_history ->
        {hand_history, get_hand_events_from_history(hand_history)}
    end
  end

  @doc """
  Get events for the previous hand (if exists).

  Queries the hand_histories projection for the most recent completed hand.

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
    # Query hand_histories for most recent completed hand
    case get_latest_completed_hand(table_id) do
      nil ->
        {:error, :no_previous_hand}

      hand_history ->
        events = get_hand_events_from_history(hand_history)

        {:ok, events}
    end
  end

  defp get_hand_history(table_id, hand_id) do
    import Ecto.Query

    from(h in Poker.Tables.Projections.HandHistory,
      where: h.table_id == ^table_id and h.hand_id == ^hand_id
    )
    |> Poker.Repo.one()
  end

  defp get_latest_completed_hand(table_id) do
    import Ecto.Query

    from(h in Poker.Tables.Projections.HandHistory,
      where: h.table_id == ^table_id and not is_nil(h.end_version),
      order_by: [desc: h.inserted_at],
      limit: 1
    )
    |> Poker.Repo.one()
  end

  defp get_hand_events_from_history(hand_history) do
    stream_id = "table-#{hand_history.table_id}"
    count = hand_history.end_version - hand_history.start_version

    {:ok, events} =
      Poker.EventStore.read_stream_forward(
        stream_id,
        hand_history.start_version,
        count
      )

    events
  end
end
