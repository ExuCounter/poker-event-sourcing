defmodule Poker.Tables.Commands.CreateTable do
  use Poker, :schema

  embedded_schema do
    field :creator_id, :binary_id
    field :table_id, :binary_id
    field :creator_participant_id, :binary_id
    field :settings_id, :binary_id
    field :game_mode, Ecto.Enum, values: [:cash_game, :tournament], default: :cash_game
    field :source_id, :binary_id
    embeds_one :settings, Poker.Tables.Commands.CreateTableSettings
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:table_id, :creator_id, :creator_participant_id, :settings_id, :game_mode, :source_id])
    |> Ecto.Changeset.validate_required([
      :table_id,
      :creator_id,
      :settings_id
    ])
    |> Ecto.Changeset.cast_embed(:settings, required: true)
  end
end
