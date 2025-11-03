defmodule Poker.Tables.Projections.TableSettings do
  use Poker, :schema

  schema "table_settings" do
    field :small_blind, :integer
    field :big_blind, :integer
    field :starting_stack, :integer
    field :timeout_seconds, :integer
    belongs_to :table, Poker.Tables.Projections.Table

    timestamps()
  end
end
