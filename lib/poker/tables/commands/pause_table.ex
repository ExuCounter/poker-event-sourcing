defmodule Poker.Tables.Commands.PauseTable do
  use Poker, :schema

  embedded_schema do
    field :table_id, :binary_id
    field :reason, Ecto.Enum, values: [:all_sitting_out]
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:table_id, :reason])
    |> Ecto.Changeset.validate_required([:table_id, :reason])
  end
end
