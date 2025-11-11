defmodule Poker.Tables.Commands.PostBigBlind do
  use Poker, :schema

  embedded_schema do
    field :table_id, :binary_id
    field :hand_id, :binary_id
    field :participant_id, :binary_id
    field :amount, :integer
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:table_id, :hand_id, :participant_id, :amount])
    |> Ecto.Changeset.validate_required([:table_id, :hand_id, :participant_id, :amount])
  end
end
