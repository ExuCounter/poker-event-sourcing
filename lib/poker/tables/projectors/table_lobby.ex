defmodule Poker.Tables.Projectors.TableLobby do
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

  alias Poker.Tables.Projections.TableLobby

  def max_seats(:six_max), do: 6

  project(
    %TableCreated{
      id: id,
      status: status,
      table_type: table_type,
      small_blind: small_blind,
      big_blind: big_blind,
      starting_stack: starting_stack
    },
    fn multi ->
      seats_count = max_seats(table_type)

      Ecto.Multi.insert(multi, :table, %TableLobby{
        id: id,
        small_blind: small_blind,
        big_blind: big_blind,
        starting_stack: starting_stack,
        table_type: table_type,
        seated_count: 0,
        seats_count: seats_count,
        status: status
      })
    end
  )
end
