defmodule Poker.Tables.Policy do
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
      {:error, "You are not owner of the table."}
    end
  end
end
