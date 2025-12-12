defmodule Poker.Tables.Projectors.TableList do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__

  alias Poker.Tables.Events.{
    TableCreated,
    TableFinished,
    ParticipantJoined,
    ParticipantBusted,
    TableStarted
  }

  alias Poker.Tables.Projections.TableList

  def max_seats(:six_max), do: 6

  project(%TableCreated{id: id, status: status, table_type: table_type}, fn multi ->
    seats_count = max_seats(table_type)

    Ecto.Multi.insert(multi, :table, %TableList{
      id: id,
      seated_count: 0,
      seats_count: seats_count,
      status: status
    })
  end)
end
