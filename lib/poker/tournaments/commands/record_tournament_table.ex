defmodule Poker.Tournaments.Commands.RecordTournamentTable do
  use Poker, :schema

  embedded_schema do
    field :tournament_id, :binary_id
    field :table_id, :binary_id
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:tournament_id, :table_id])
    |> Ecto.Changeset.validate_required([:tournament_id, :table_id])
  end
end
