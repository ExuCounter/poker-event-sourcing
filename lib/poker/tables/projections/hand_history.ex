defmodule Poker.Tables.Projections.HandHistory do
  use Poker, :schema

  schema "hand_histories" do
    field :hand_id, :binary_id
    field :table_id, :binary_id
    field :start_version, :integer
    field :end_version, :integer
    field :initial_state, :binary

    timestamps()
  end
end
