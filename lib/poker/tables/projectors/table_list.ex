defmodule Poker.Tables.Projectors.TableList do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Tables.Events.{
    TableCreated,
    TableFinished,
    ParticipantJoined,
    ParticipantBusted,
    TableStarted
  }

  alias Poker.Tables.Projections.TableList

  def max_seats(:six_max), do: 6

  def table_query(id), do: from(t in TableList, where: t.id == ^id)

  project(%TableCreated{id: id, status: status, table_type: table_type}, fn multi ->
    seats_count = max_seats(table_type)

    Ecto.Multi.insert(multi, :table, %TableList{
      id: id,
      seated_count: 0,
      seats_count: seats_count,
      status: status
    })
  end)

  project(%TableStarted{id: table_id, status: status}, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(table_id), set: [status: status])
  end)

  project(%ParticipantJoined{table_id: table_id}, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(table_id), inc: [seated_count: 1])
  end)

  project(%ParticipantBusted{table_id: table_id}, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(table_id), inc: [seated_count: -1])
  end)

  project(%TableFinished{table_id: table_id}, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(table_id), set: [status: :finished])
  end)

  @impl Commanded.Projections.Ecto
  def after_update(%TableCreated{id: table_id}, _metadata, _changes) do
    broadcast_table_list(table_id, :table_created)
  end

  def after_update(%TableStarted{id: table_id}, _metadata, _changes) do
    broadcast_table_list(table_id, :table_started)
  end

  def after_update(%ParticipantJoined{table_id: table_id}, _metadata, _changes) do
    broadcast_table_list(table_id, :participant_joined)
  end

  def after_update(%ParticipantBusted{table_id: table_id}, _metadata, _changes) do
    broadcast_table_list(table_id, :participant_busted)
  end

  def after_update(%TableFinished{table_id: table_id}, _metadata, _changes) do
    broadcast_table_list(table_id, :table_finished)
  end

  defp broadcast_table_list(table_id, event) do
    Phoenix.PubSub.broadcast(Poker.PubSub, "table_list", {:table_list_updated, table_id, event})
    :ok
  end
end
