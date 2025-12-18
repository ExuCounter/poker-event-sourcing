defmodule Poker.Tables.Projections.TableHands do
  use Poker, :schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "table_hands" do
    belongs_to :table, Poker.Tables.Projections.Table, type: :binary_id

    field :status, Ecto.Enum, values: [:active, :finished]

    has_many(:rounds, Poker.Tables.Projections.TableRounds, foreign_key: :hand_id)
    has_many(:pots, Poker.Tables.Projections.TablePots, foreign_key: :hand_id)

    has_many(:participant_hands, Poker.Tables.Projections.TableParticipantHands,
      foreign_key: :hand_id
    )

    timestamps()
  end
end
