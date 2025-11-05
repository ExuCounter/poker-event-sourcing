defmodule Poker.Tables.Commands.CreateTable do
  use Poker, :schema

  embedded_schema do
    field :creator_id, :binary_id
    field :table_uuid, :string
    embeds_one :settings, Poker.Tables.Commands.CreateTableSettings
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:table_uuid, :creator_id])
    |> Ecto.Changeset.validate_required([:table_uuid, :creator_id])
    |> Ecto.Changeset.cast_embed(:settings, required: true)
  end
end
