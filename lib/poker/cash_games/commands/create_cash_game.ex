defmodule Poker.CashGames.Commands.CreateCashGame do
  use Poker, :schema

  embedded_schema do
    field :cash_game_id, :binary_id
    field :table_id, :binary_id
    field :creator_id, :binary_id
    field :small_blind, :integer
    field :big_blind, :integer
    field :min_buyin, :integer
    field :max_buyin, :integer
    field :table_type, Ecto.Enum, values: [:two_max, :three_max, :four_max, :six_max]
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [
      :cash_game_id,
      :table_id,
      :creator_id,
      :small_blind,
      :big_blind,
      :min_buyin,
      :max_buyin,
      :table_type
    ])
    |> Ecto.Changeset.validate_required([
      :cash_game_id,
      :table_id,
      :creator_id,
      :small_blind,
      :big_blind,
      :min_buyin,
      :max_buyin,
      :table_type
    ])
    |> Ecto.Changeset.validate_number(:small_blind, greater_than: 0)
    |> Ecto.Changeset.validate_number(:big_blind, greater_than: 0)
    |> Ecto.Changeset.validate_number(:min_buyin, greater_than: 0)
    |> Ecto.Changeset.validate_number(:max_buyin, greater_than: 0)
  end
end
