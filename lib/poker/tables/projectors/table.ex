defmodule Poker.Tables.Projectors.Table do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Tables.Events.{TableCreated, TableStarted, TableFinished}
  alias Poker.Tables.Projections.Table

  import Ecto.Query

  def table_query(id), do: from(t in Table, where: t.id == ^id)

  project(%TableCreated{id: id, status: status}, fn multi ->
    Ecto.Multi.insert(multi, :table, %Table{id: id, status: status})
  end)

  project(%TableStarted{id: id, status: status}, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(id), set: [status: status])
  end)

  project(%TableFinished{table_id: id}, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(id), set: [status: :finished])
  end)

  @impl Commanded.Projections.Ecto
  def after_update(%TableCreated{id: table_id}, _metadata, _changes) do
    broadcast_table(table_id, :table_created)
  end

  def after_update(%TableStarted{id: table_id}, _metadata, _changes) do
    broadcast_table(table_id, :table_started)
  end

  def after_update(%TableFinished{table_id: table_id}, _metadata, _changes) do
    broadcast_table(table_id, :table_finished)
  end

  defp broadcast_table(table_id, event) do
    Phoenix.PubSub.broadcast(Poker.PubSub, "table:#{table_id}", {:table_updated, event})
    :ok
  end
end
