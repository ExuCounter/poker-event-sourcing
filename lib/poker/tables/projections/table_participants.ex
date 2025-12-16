defmodule Poker.Tables.Projections.TableParticipants do
  use Poker, :schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "table_participants" do
    belongs_to :table, Poker.Tables.Projections.Table, type: :binary_id
    belongs_to :player, Poker.Accounts.User, type: :binary_id

    field :chips, :integer
    field :status, Ecto.Enum, values: [:active, :busted]
    field :is_sitting_out, :boolean

    timestamps()
  end
end
