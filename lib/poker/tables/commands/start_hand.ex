defmodule Poker.Tables.Commands.StartHand do
  use Poker, :schema

  embedded_schema do
    field :hand_id, :binary_id
    field :table_id, :binary_id
    field :dealer_button_id, :binary_id
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:hand_id, :table_id, :dealer_button_id])
    |> Ecto.Changeset.validate_required([:hand_id, :table_id, :dealer_button_id])
  end
end
