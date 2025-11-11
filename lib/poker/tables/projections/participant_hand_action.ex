defmodule Poker.Tables.Projections.ParticipantHandAction do
  use Poker, :schema

  schema "table_participant_hand_actions" do
    belongs_to(:participant, Poker.Tables.Projections.Participant)
    belongs_to(:table_hand, Poker.Tables.Projections.Hand)
    field(:action, Ecto.Enum, values: [:fold, :check, :call, :raise, :all_in])
    field(:amount, :integer)
    field(:round, Ecto.Enum, values: [:pre_flop, :flop, :turn, :river])

    timestamps()
  end
end
