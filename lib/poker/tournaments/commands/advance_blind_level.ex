defmodule Poker.Tournaments.Commands.AdvanceBlindLevel do
  use Poker, :schema

  embedded_schema do
    field :tournament_id, :binary_id
    field :level, :integer
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:tournament_id, :level])
    |> Ecto.Changeset.validate_required([:tournament_id, :level])
  end
end
