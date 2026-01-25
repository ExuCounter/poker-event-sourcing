defmodule Poker.Tables.Projectors.HandHistory do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  project(%Poker.Tables.Events.HandStarted{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :hand_index, %HandIndex{
      hand_id: event.id,
      table_id: event.table_id,
      start_version: metadata.stream_version,
      started_at: metadata.created_at
    })
  end)

  project(%Poker.Tables.Events.HandFinished{} = event, metadata, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :hand_index,
      from(h in HandIndex, where: h.hand_id == ^event.hand_id),
      set: [
        end_version: metadata.stream_version,
        finished_at: metadata.created_at
      ]
    )
  end)
end
