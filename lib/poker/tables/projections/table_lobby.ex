defmodule Poker.Tables.Projections.TableLobby do
  use Poker, :schema

  schema "table_lobby" do
    field :small_blind, :integer
    field :big_blind, :integer
    field :starting_stack, :integer
    field :table_type, Ecto.Enum, values: [:six_max]
    field :seated_count, :integer
    field :seats_count, :integer
    field :status, Ecto.Enum, values: [:waiting, :playing, :finished]

    timestamps()
  end
end
