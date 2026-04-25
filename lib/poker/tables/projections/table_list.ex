defmodule Poker.Tables.Projections.TableList do
  use Poker, :schema

  schema "table_list" do
    field :seated_count, :integer
    field :seats_count, :integer
    field :status, Ecto.Enum, values: [:waiting, :live, :paused, :finished]
    field :game_mode, Ecto.Enum, values: [:cash_game, :tournament]
    field :source_id, :binary_id

    timestamps()
  end
end
