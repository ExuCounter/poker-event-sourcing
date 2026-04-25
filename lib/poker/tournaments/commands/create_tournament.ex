defmodule Poker.Tournaments.Commands.CreateTournament do
  use Poker, :schema

  embedded_schema do
    field :tournament_id, :binary_id
    field :creator_id, :binary_id
    field :speed, Ecto.Enum, values: [:regular, :turbo, :hyper_turbo]
    field :buy_in, :integer
    field :table_type, Ecto.Enum, values: [:two_max, :three_max, :four_max, :six_max]
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [
      :tournament_id,
      :creator_id,
      :speed,
      :buy_in,
      :table_type
    ])
    |> Ecto.Changeset.validate_required([
      :tournament_id,
      :creator_id,
      :speed,
      :buy_in,
      :table_type
    ])
    |> Ecto.Changeset.validate_number(:buy_in, greater_than: 0)
  end
end
