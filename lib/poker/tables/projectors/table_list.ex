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
    TableStarted,
    TablePaused,
    TableResumed
  }

  alias Poker.Tables.Projections.TableList

  def max_seats(:two_max), do: 2
  def max_seats(:three_max), do: 3
  def max_seats(:four_max), do: 4
  def max_seats(:six_max), do: 6

  def table_query(id), do: from(t in TableList, where: t.id == ^id)

  project(%TableCreated{id: id, status: status, table_type: table_type, source_id: source_id, game_mode: game_mode}, fn multi ->
    seats_count = max_seats(table_type)

    Ecto.Multi.insert(multi, :table, %TableList{
      id: id,
      seated_count: 0,
      seats_count: seats_count,
      status: status,
      game_mode: game_mode,
      source_id: source_id
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

  project(%TablePaused{table_id: table_id}, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(table_id), set: [status: :paused])
  end)

  project(%TableResumed{table_id: table_id}, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(table_id), set: [status: :live])
  end)

  @impl Commanded.Projections.Ecto
  def after_update(%TableCreated{id: table_id}, _metadata, _changes) do
    Poker.Tables.PubSub.broadcast_table_list(table_id, :table_created)
  end

  def after_update(%TableStarted{id: table_id}, _metadata, _changes) do
    Poker.Tables.PubSub.broadcast_table_list(table_id, :table_started)
  end

  def after_update(
        %ParticipantJoined{table_id: table_id, id: participant_id},
        _metadata,
        _changes
      ) do
    Poker.Tables.PubSub.broadcast_table_list(table_id, :participant_joined, %{
      participant_id: participant_id
    })
  end

  def after_update(
        %ParticipantBusted{table_id: table_id, participant_id: participant_id},
        _metadata,
        _changes
      ) do
    Poker.Tables.PubSub.broadcast_table_list(table_id, :participant_busted, %{
      participant_id: participant_id
    })
  end

  def after_update(%TableFinished{table_id: table_id}, _metadata, _changes) do
    Poker.Tables.PubSub.broadcast_table_list(table_id, :table_finished)
  end

  def after_update(%TablePaused{table_id: table_id}, _metadata, _changes) do
    Poker.Tables.PubSub.broadcast_table_list(table_id, :table_paused)
  end

  def after_update(%TableResumed{table_id: table_id}, _metadata, _changes) do
    Poker.Tables.PubSub.broadcast_table_list(table_id, :table_resumed)
  end
end
