defmodule Poker.Tables.Projections.TablePotWinners do
  use Poker, :schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "table_pot_winners" do
    belongs_to :hand, Poker.Tables.Projections.TableHands, type: :binary_id
    belongs_to :pot, Poker.Tables.Projections.TablePots, type: :binary_id
    belongs_to :participant, Poker.Tables.Projections.TableParticipants, type: :binary_id

    field :amount, :integer

    timestamps()
  end
end
