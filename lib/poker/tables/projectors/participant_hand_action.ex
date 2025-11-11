defmodule Poker.Tables.Projectors.ParticipantHandAction do
  use Commanded.Projections.Ecto,
    name: "Tables.Projectors.ParticipantHandAction",
    repo: Poker.Repo,
    application: Poker.App,
    consistency: :strong

  project(%Poker.Tables.Events.ParticipantActedInHand{} = acted, fn multi ->
    Ecto.Multi.insert(
      multi,
      :participant_hand_action,
      %Poker.Tables.Projections.ParticipantHandAction{
        id: acted.id,
        participant_id: acted.participant_id,
        table_hand_id: acted.table_hand_id,
        action: acted.action |> String.to_existing_atom(),
        amount: acted.amount,
        round: acted.round |> String.to_existing_atom()
      }
    )
  end)
end
