defmodule Poker.Tables.Projectors.ParticipantHand do
  use Commanded.Projections.Ecto,
    name: "Tables.Projectors.ParticipantHand",
    repo: Poker.Repo,
    application: Poker.App,
    consistency: :strong

  project(%Poker.Tables.Events.ParticipantHandGiven{} = given, fn multi ->
    Ecto.Multi.insert(
      multi,
      :participant_hand,
      %Poker.Tables.Projections.ParticipantHand{
        id: given.id,
        table_id: given.table_id,
        participant_id: given.participant_id,
        table_hand_id: given.table_hand_id,
        hole_cards: given.hole_cards,
        position: given.position |> String.to_existing_atom()
      }
    )
  end)
end
