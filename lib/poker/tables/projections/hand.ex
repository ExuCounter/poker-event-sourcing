defmodule Poker.Tables.Projections.Hand do
  use Poker, :schema

  schema "table_hands" do
    belongs_to(:table, Poker.Tables.Projections.Table)
    belongs_to(:dealer_button, Poker.Tables.Projections.Participant)
    belongs_to(:participant_to_act, Poker.Tables.Projections.Participant)

    field(:current_round, Ecto.Enum,
      values: [:not_started, :pre_flop, :flop, :turn, :river],
      default: :not_started
    )

    field(:flop_cards, {:array, Poker.Ecto.Card})
    field(:turn_card, Poker.Ecto.Card)
    field(:river_card, Poker.Ecto.Card)

    has_many(:participant_hands, Poker.Tables.Projections.ParticipantHand,
      foreign_key: :table_hand_id
    )

    has_many(:pots, Poker.Tables.Projections.Pot, foreign_key: :hand_id)

    timestamps()
  end
end
