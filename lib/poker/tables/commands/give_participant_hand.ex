defmodule Poker.Tables.Commands.GiveParticipantHand do
  use Poker, :schema

  embedded_schema do
    field :participant_hand_id, :binary_id
    field :table_id, :binary_id
    field :participant_id, :binary_id
    field :table_hand_id, :binary_id
    field :hole_cards, {:array, Poker.Ecto.Card}
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:participant_hand_id, :table_id, :participant_id, :table_hand_id, :hole_cards])
    |> Ecto.Changeset.validate_required([:participant_hand_id, :table_id, :participant_id, :table_hand_id, :hole_cards])
    |> Ecto.Changeset.validate_length(:hole_cards, is: 2)
  end
end
