defmodule Poker.Tables.Commands.TimeoutParticipant do
  use Poker, :schema

  embedded_schema do
    field :table_id, :binary_id
    field :participant_id, :binary_id
    field :round_id, :binary_id
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:table_id, :participant_id, :round_id])
    |> Ecto.Changeset.validate_required([:table_id, :participant_id, :round_id])
  end
end
