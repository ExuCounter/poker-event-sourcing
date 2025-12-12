defmodule Poker.Tables.Projections.TableList do
  use Poker, :schema

  schema "table_list" do
    field :seated_count, :integer
    field :seats_count, :integer
    field :status, Ecto.Enum, values: [:waiting, :live, :finished]

    timestamps()
  end
end
