defmodule Poker.Tables.Commands.FinishTable do
  use Poker, :schema

  embedded_schema do
    field :table_id, :binary_id
    field :reason, Ecto.Enum, values: [:completed]
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:table_id, :reason])
    |> Ecto.Changeset.validate_required([:table_id, :reason])
  end
end
