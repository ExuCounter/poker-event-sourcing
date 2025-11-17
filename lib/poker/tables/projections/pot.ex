defmodule Poker.Tables.Projections.Pot do
  use Poker, :schema

  schema "table_hand_pots" do
    belongs_to(:hand, Poker.Tables.Projections.Hand)

    field(:type, Ecto.Enum, values: [:main, :side])
    field(:total_amount, :integer, default: 0)

    timestamps()
  end
end
