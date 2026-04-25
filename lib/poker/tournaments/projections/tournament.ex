defmodule Poker.Tournaments.Projections.Tournament do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: false}

  schema "tournaments" do
    field :creator_id, :binary_id
    field :status, Ecto.Enum, values: [:registering, :active, :finished]
    field :speed, Ecto.Enum, values: [:regular, :turbo, :hyper_turbo]
    field :buy_in, :integer
    field :starting_stack, :integer
    field :table_type, Ecto.Enum, values: [:two_max, :three_max, :four_max, :six_max]
    field :max_players, :integer
    field :registered_count, :integer, default: 0
    field :players_remaining, :integer, default: 0
    field :current_level, :integer, default: 1
    field :prize_pool, :integer, default: 0
    field :player_ids, {:array, :binary_id}, default: []
    field :level_started_at, :utc_datetime_usec

    timestamps()
  end
end
