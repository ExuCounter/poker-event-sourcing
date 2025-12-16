defmodule Poker.Tables.Projections.TableRounds do
  use Poker, :schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "table_rounds" do
    belongs_to :hand, Poker.Tables.Projections.TableHands, type: :binary_id
    belongs_to :participant_to_act, Poker.Tables.Projections.TableParticipants, type: :binary_id

    field :round_type, Ecto.Enum, values: [:preflop, :flop, :turn, :river]
    field :community_cards, {:array, Poker.Ecto.Card}

    timestamps()
  end
end
