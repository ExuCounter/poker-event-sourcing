defmodule Poker.Router do
  use Commanded.Commands.Router
  alias Poker.Accounts.Commands.{RegisterPlayer}
  alias Poker.Tables.Commands.{CreateTable, CreateTableSettings, JoinTableParticipant}
  alias Poker.Accounts.Aggregates.{Player}
  alias Poker.Tables.Aggregates.{Table}

  identify(Player, by: :player_uuid)
  identify(Table, by: :table_uuid)

  dispatch(
    [
      RegisterPlayer
    ],
    to: Player
  )

  dispatch(
    [
      CreateTable,
      CreateTableSettings,
      JoinTableParticipant
    ],
    to: Table
  )
end
