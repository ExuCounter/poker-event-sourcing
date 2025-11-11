defmodule Poker.Tables.Projections.Participant do
  use Poker, :schema

  schema "table_participants" do
    field(:chips, :integer)
    field(:status, Ecto.Enum, values: [:active, :folded])
    field(:seat_number, :integer)
    field(:is_sitting_out, :boolean)

    belongs_to(:player, Poker.Accounts.Projections.Player)
    belongs_to(:table, Poker.Tables.Projections.Table)

    timestamps()
  end
end
