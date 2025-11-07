defmodule Poker.Tables.Commands.StartTable do
  use Poker, :schema

  embedded_schema do
    field :table_id, :binary_id
    field :hand_id, :binary_id
    field :dealer_button_id, :binary_id
    field :dealt_cards, {:array, :map}
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:table_id, :hand_id, :dealer_button_id, :dealt_cards])
    |> Ecto.Changeset.validate_required([:table_id, :hand_id, :dealer_button_id, :dealt_cards])
  end
end
