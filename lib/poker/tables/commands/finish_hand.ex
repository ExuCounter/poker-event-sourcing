defmodule Poker.Tables.Commands.FinishHand do
  use Poker, :schema

  embedded_schema do
    field :hand_id, :binary_id
    field :table_id, :binary_id
    field :finish_reason, Ecto.Enum, values: [:showdown, :all_in_runout, :all_folded]
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:hand_id, :table_id, :finish_reason])
    |> Ecto.Changeset.validate_required([:hand_id, :table_id, :finish_reason])
  end
end
