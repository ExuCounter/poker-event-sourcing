defmodule Poker.Tournaments.Commands.RecordPlayerBust do
  use Poker, :schema

  embedded_schema do
    field :tournament_id, :binary_id
    field :player_id, :binary_id
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:tournament_id, :player_id])
    |> Ecto.Changeset.validate_required([:tournament_id, :player_id])
  end
end
