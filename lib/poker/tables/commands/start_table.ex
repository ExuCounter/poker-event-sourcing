defmodule Poker.Tables.Commands.StartTable do
  use Poker, :schema

  embedded_schema do
    field :table_id, :binary_id
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:table_id])
    |> Ecto.Changeset.validate_required([:table_id])
  end
end
