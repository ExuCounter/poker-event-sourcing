defmodule Poker.Tables.Aggregates.Table do
  use Poker, :schema
  alias Poker.Tables.Aggregates.Table

  embedded_schema do
    field :creator_id, :binary_id
    field :status, Ecto.Enum, values: [:not_started, :live, :finished], default: :not_started
  end

  alias Poker.Tables.Commands.{CreateTable}
  alias Poker.Tables.Events.{TableCreated}

  def execute(%Table{}, %CreateTable{} = create) do
    %TableCreated{
      id: create.table_uuid,
      creator_id: create.creator_id,
      settings: create.settings,
      status: :not_started
    }
  end

  # State mutators

  def apply(%Table{} = _table, %TableCreated{} = created) do
    %Table{
      id: created.id,
      creator_id: created.creator_id,
      status: created.status
    }
  end
end
