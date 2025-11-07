defmodule Poker.Tables.Projectors.TableParticipant do
  use Commanded.Projections.Ecto,
    name: "Tables.Projectors.TableParticipant",
    repo: Poker.Repo,
    application: Poker.App,
    consistency: :strong

  project(%Poker.Tables.Events.TableParticipantJoined{} = joined, fn multi ->
    Ecto.Multi.insert(
      multi,
      :table_participant,
      %Poker.Tables.Projections.TableParticipant{
        id: joined.id,
        player_id: joined.player_id,
        table_id: joined.table_id,
        chips: joined.chips,
        seat_number: joined.seat_number,
        status: joined.status |> String.to_existing_atom()
      },
      on_conflict: :nothing,
      conflict_target: [:table_id, :player_id]
    )
  end)
end
