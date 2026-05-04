defmodule Poker.Tables.Projections.HandSummary do
  use Poker, :schema

  schema "hand_summaries" do
    field :hand_id, :binary_id
    field :table_id, :binary_id
    field :game_mode, Ecto.Enum, values: [:cash_game, :tournament]
    field :source_id, :binary_id
    field :pot_total, :integer, default: 0
    field :finish_reason, Ecto.Enum, values: [:showdown, :all_folded, :all_in_runout]
    field :winner_player_id, :binary_id
    field :winner_hand_rank, :string

    timestamps()
  end
end
