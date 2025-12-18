defmodule Poker.Tables.Projections.Table do
  use Poker, :schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "tables" do
    field :status, Ecto.Enum, values: [:waiting, :live, :finished]

    has_many(:hands, Poker.Tables.Projections.TableHands)
    has_many(:participants, Poker.Tables.Projections.TableParticipants)

    timestamps()
  end
end
