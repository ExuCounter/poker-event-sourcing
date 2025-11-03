defmodule Poker.Router do
  use Commanded.Commands.Router
  alias Poker.Accounts.Commands.{RegisterPlayer}
  alias Poker.Tables.Commands.{CreateTable, CreateTableSettings}
  alias Poker.Accounts.Aggregates.{Player}
  alias Poker.Tables.Aggregates.{Table, TableSettings}

  identify(Player, by: :player_uuid)
  identify(Table, by: :table_uuid)
  identify(TableSettings, by: :settings_uuid)

  dispatch(
    [
      RegisterPlayer
    ],
    to: Player
  )

  dispatch(
    [
      CreateTable
    ],
    to: Table
  )

  dispatch(
    [
      CreateTableSettings
    ],
    to: TableSettings
  )
end
