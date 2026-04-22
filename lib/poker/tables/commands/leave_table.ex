defmodule Poker.Tables.Commands.LeaveTable do
  use Poker, :schema

  embedded_schema do
    field :player_id, :binary_id
    field :table_id, :binary_id
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:player_id, :table_id])
    |> Ecto.Changeset.validate_required([:player_id, :table_id])
  end
end
