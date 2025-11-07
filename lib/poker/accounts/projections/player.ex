defmodule Poker.Accounts.Projections.Player do
  use Poker, :schema

  schema "players" do
    field(:email, :string)
    has_many(:table_participants, Poker.Tables.Projections.Participant, foreign_key: :player_id)

    timestamps()
  end
end
