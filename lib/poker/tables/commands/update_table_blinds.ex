defmodule Poker.Tables.Commands.UpdateTableBlinds do
  use Poker, :schema

  embedded_schema do
    field :table_id, :binary_id
    field :small_blind, :integer
    field :big_blind, :integer
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:table_id, :small_blind, :big_blind])
    |> Ecto.Changeset.validate_required([:table_id, :small_blind, :big_blind])
    |> Ecto.Changeset.validate_number(:small_blind, greater_than: 0)
    |> Ecto.Changeset.validate_number(:big_blind, greater_than: 0)
  end
end
