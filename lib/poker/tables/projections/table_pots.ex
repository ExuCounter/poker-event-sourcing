defmodule Poker.Tables.Projections.TablePots do
  use Poker, :schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "table_pots" do
    belongs_to :hand, Poker.Tables.Projections.TableHands, type: :binary_id

    has_many(:winners, Poker.Tables.Projections.TablePotWinners, foreign_key: :pot_id)

    field :amount, :integer

    timestamps()
  end
end
