defmodule Poker.Tables.Projections.Table do
  use Poker, :schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "tables" do
    field :status, Ecto.Enum, values: [:waiting, :live, :finished]

    timestamps()
  end
end
