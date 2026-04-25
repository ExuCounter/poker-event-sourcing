defmodule Poker.Tournaments.Commands.FinishTournament do
  use Poker, :schema

  embedded_schema do
    field :tournament_id, :binary_id
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:tournament_id])
    |> Ecto.Changeset.validate_required([:tournament_id])
  end
end
