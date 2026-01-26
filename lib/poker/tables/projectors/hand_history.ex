defmodule Poker.Tables.Projectors.HandHistory do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  import Ecto.Query

  project(%Poker.Tables.Events.HandStarted{} = event, metadata, fn multi ->
    initial_state =
      case find_previous_hand(event.table_id) |> dbg() do
        nil ->
          %Poker.Tables.Aggregates.Table{}
          |> replay_events_from(
            event.table_id,
            0,
            metadata.stream_version
          )

        previous_hand ->
          previous_hand.initial_state
          |> :erlang.binary_to_term()
          |> replay_events_from(
            event.table_id,
            previous_hand.start_version,
            metadata.stream_version
          )
      end

    Ecto.Multi.insert(multi, :hand_index, %Poker.Tables.Projections.HandHistory{
      hand_id: event.id,
      table_id: event.table_id,
      start_version: metadata.stream_version,
      initial_state: initial_state |> :erlang.term_to_binary()
    })
  end)

  project(%Poker.Tables.Events.HandFinished{} = event, metadata, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :hand_index,
      from(h in Poker.Tables.Projections.HandHistory, where: h.hand_id == ^event.hand_id),
      set: [end_version: metadata.stream_version]
    )
  end)

  defp find_previous_hand(table_id) do
    from(h in Poker.Tables.Projections.HandHistory,
      where: h.table_id == ^table_id,
      order_by: [desc: h.hand_id],
      limit: 1
    )
    |> Poker.Repo.one()
  end

  defp replay_events_from(state, table_id, from_version, to_version) do
    stream = "table-#{table_id}"

    {:ok, new_events} =
      stream
      |> Poker.EventStore.read_stream_forward(from_version, to_version - from_version)

    Enum.reduce(new_events, state, fn event, acc ->
      Poker.Tables.Aggregates.Table.apply(acc, event.data)
    end)
  end
end
