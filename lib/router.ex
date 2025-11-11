defmodule Poker.Router do
  use Commanded.Commands.Router
  alias Poker.Accounts.Commands.{RegisterPlayer}

  alias Poker.Tables.Commands.{
    CreateTable,
    CreateTableSettings,
    JoinTableParticipant,
    StartHand,
    GiveParticipantHand,
    StartTable,
    ParticipantActInHand,
    SitInParticipant,
    SitOutParticipant
  }

  alias Poker.Accounts.Aggregates.{Player}
  alias Poker.Tables.Aggregates.{Table}

  identify(Player, by: :player_id, prefix: "player-")
  identify(Table, by: :table_id, prefix: "table-")

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
      JoinTableParticipant,
      StartTable,
      StartHand,
      GiveParticipantHand,
      ParticipantActInHand,
      SitInParticipant,
      SitOutParticipant
    ],
    to: Table
  )
end
