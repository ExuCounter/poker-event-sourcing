defmodule Poker.Tables.Projections.TableParticipants do
  use Poker, :schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "table_participants" do
    belongs_to :table, Poker.Tables.Projections.Table
    belongs_to :player, Poker.Accounts.Schemas.User

    field :chips, :integer
    field :status, Ecto.Enum, values: [:active, :busted]
    field :is_sitting_out, :boolean

    timestamps()
  end
end
