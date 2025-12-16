defmodule Poker.Tables.Projections.TableHands do
  use Poker, :schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "table_hands" do
    belongs_to :table, Poker.Tables.Projections.Table, type: :binary_id

    field :status, Ecto.Enum, values: [:active, :finished]

    timestamps()
  end
end
