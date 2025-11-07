defmodule Poker.Tables.Projections.TableParticipant do
  use Poker, :schema

  schema "table_participants" do
    field(:chips, :integer)
    field(:status, Ecto.Enum, values: [:active, :sitting_out])
    field(:seat_number, :integer)
    belongs_to(:player, Poker.Accounts.Projections.Player)
    belongs_to(:table, Poker.Tables.Projections.Table)

    timestamps()
  end
end
