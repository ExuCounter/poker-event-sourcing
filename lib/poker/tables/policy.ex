defmodule Poker.Tables.Policy do
  @moduledoc """
  Authorization policy for table operations.

  Implements Bodyguard.Policy to authorize user actions on tables.
  Currently handles owner-only operations like starting a table.
  """

  @behaviour Bodyguard.Policy

  def aggregate_table(table_id) do
    Commanded.Aggregates.Aggregate.aggregate_state(
      Poker.App,
      Poker.Tables.Aggregates.Table,
      "table-" <> table_id
    )
  end

  def authorize(:start_table, %{user: user} = _scope, table_id) do
    table = aggregate_table(table_id)

    if table.creator_id == user.id do
      :ok
    else
      {:error, :not_table_owner}
    end
  end
end
