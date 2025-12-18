defmodule Poker.Tables.Projections.TableParticipantHands do
  use Poker, :schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "table_participant_hands" do
    belongs_to :hand, Poker.Tables.Projections.TableHands, type: :binary_id
    belongs_to :participant, Poker.Tables.Projections.TableParticipants, type: :binary_id

    field :hole_cards, {:array, Poker.Ecto.Card}

    field :position, Ecto.Enum,
      values: [:dealer, :small_blind, :big_blind, :utg, :hijack, :cutoff]

    field :status, Ecto.Enum, values: [:playing, :folded, :all_in]
    field :bet_this_round, :integer

    timestamps()
  end
end
