defmodule Poker.Tables.Projections.PotEligibility do
  use Poker, :schema

  schema "table_hand_pot_eligibilities" do
    belongs_to(:pot, Poker.Tables.Projections.Pot)
    belongs_to(:participant, Poker.Tables.Projections.Participant)

    timestamps()
  end
end
