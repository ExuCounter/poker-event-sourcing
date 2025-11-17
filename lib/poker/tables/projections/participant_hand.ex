defmodule Poker.Tables.Projections.ParticipantHand do
  use Poker, :schema

  schema "table_participant_hands" do
    belongs_to(:table, Poker.Tables.Projections.Table)
    belongs_to(:participant, Poker.Tables.Projections.Participant)
    belongs_to(:table_hand, Poker.Tables.Projections.Hand)

    field(:hole_cards, {:array, Poker.Ecto.Card}, default: [])
    field(:position, Ecto.Enum,
      values: [:dealer, :small_blind, :big_blind, :utg, :utg_plus_1, :utg_plus_2, :lojack, :hijack, :cutoff]
    )

    timestamps()
  end
end
