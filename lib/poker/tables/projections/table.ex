defmodule Poker.Tables.Projections.Table do
  use Poker, :schema

  schema "tables" do
    field(:status, Ecto.Enum, values: [:not_started, :live, :finished])
    belongs_to(:creator, Poker.Accounts.Projections.Player)
    has_one(:settings, Poker.Tables.Projections.TableSettings, foreign_key: :table_id)
    has_many(:participants, Poker.Tables.Projections.TableParticipant, foreign_key: :table_id)

    timestamps()
  end
end
