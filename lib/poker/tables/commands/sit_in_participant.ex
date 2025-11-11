defmodule Poker.Tables.Commands.SitInParticipant do
  use Poker, :schema

  embedded_schema do
    field :participant_id, :binary_id
    field :table_id, :binary_id
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:participant_id, :table_id])
    |> Ecto.Changeset.validate_required([:participant_id, :table_id])
  end
end
