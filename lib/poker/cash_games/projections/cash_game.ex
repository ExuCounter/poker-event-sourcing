defmodule Poker.CashGames.Projections.CashGame do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: false}

  schema "cash_games" do
    field :table_id, :binary_id
    field :creator_id, :binary_id
    field :small_blind, :integer
    field :big_blind, :integer
    field :min_buyin, :integer
    field :max_buyin, :integer
    field :table_type, Ecto.Enum, values: [:two_max, :three_max, :four_max, :six_max]

    # Virtual field populated by join with tables
    field :table_status, Ecto.Enum, values: [:waiting, :live, :paused, :finished], virtual: true

    timestamps()
  end
end
