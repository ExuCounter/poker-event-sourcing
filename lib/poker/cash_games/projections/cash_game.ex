defmodule Poker.CashGames.Projections.CashGame do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: false}

  schema "cash_games" do
    field :table_id, :binary_id
    field :creator_id, :binary_id
    field :status, Ecto.Enum, values: [:active, :closed]
    field :small_blind, :integer
    field :big_blind, :integer
    field :min_buyin, :integer
    field :max_buyin, :integer
    field :table_type, Ecto.Enum, values: [:six_max]

    timestamps()
  end
end
