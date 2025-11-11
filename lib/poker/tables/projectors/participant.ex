defmodule Poker.Tables.Projectors.Participant do
  use Commanded.Projections.Ecto,
    name: "Tables.Projectors.Participant",
    repo: Poker.Repo,
    application: Poker.App,
    consistency: :strong

  project(%Poker.Tables.Events.TableParticipantJoined{} = joined, fn multi ->
    Ecto.Multi.insert(
      multi,
      :table_participant,
      %Poker.Tables.Projections.Participant{
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

  project(%Poker.Tables.Events.ParticipantSatOut{} = event, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :participant_sat_out,
      fn _ ->
        from(p in Poker.Tables.Projections.Participant,
          where: p.id == ^event.participant_id
        )
      end,
      set: [is_sitting_out: true]
    )
  end)

  project(%Poker.Tables.Events.ParticipantSatIn{} = event, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :participant_sat_in,
      fn _ ->
        from(p in Poker.Tables.Projections.Participant,
          where: p.id == ^event.participant_id
        )
      end,
      set: [is_sitting_out: false]
    )
  end)

  project(%Poker.Tables.Events.SmallBlindPosted{} = event, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :small_blind_posted,
      fn _ ->
        from(p in Poker.Tables.Projections.Participant,
          where: p.id == ^event.participant_id
        )
      end,
      inc: [chips: -event.amount]
    )
  end)

  project(%Poker.Tables.Events.BigBlindPosted{} = event, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :big_blind_posted,
      fn _ ->
        from(p in Poker.Tables.Projections.Participant,
          where: p.id == ^event.participant_id
        )
      end,
      inc: [chips: -event.amount]
    )
  end)
end
