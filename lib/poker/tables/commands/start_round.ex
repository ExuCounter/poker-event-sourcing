defmodule Poker.Tables.Commands.StartRound do
  use Poker, :schema

  embedded_schema do
    field :round_id, :binary_id
    field :table_id, :binary_id
    field :hand_id, :binary_id
    field :round, Ecto.Enum, values: [:pre_flop, :flop, :turn, :river]
    field :community_cards, {:array, Poker.Ecto.Card}
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:round_id, :table_id, :hand_id, :round, :community_cards])
    |> Ecto.Changeset.validate_required([
      :round_id,
      :table_id,
      :hand_id,
      :round,
      :community_cards
    ])
  end
end
