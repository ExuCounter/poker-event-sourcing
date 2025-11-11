defmodule Poker.Tables.Projections.ParticipantHand do
  use Poker, :schema

  schema "table_participant_hands" do
    belongs_to(:table, Poker.Tables.Projections.Table)
    belongs_to(:participant, Poker.Tables.Projections.Participant)
    belongs_to(:table_hand, Poker.Tables.Projections.Hand)

    field(:hole_cards, {:array, Poker.Ecto.Card}, default: [])

    timestamps()
  end
end
