defmodule Poker.Router do
  use Commanded.Commands.Router

  alias Poker.Tables.Commands.{
    CreateTable,
    CreateTableSettings,
    JoinTableParticipant,
    StartHand,
    GiveParticipantHand,
    StartTable,
    ParticipantActInHand,
    SitInParticipant,
    SitOutParticipant,
    StartRound,
    FinishHand
  }

  alias Poker.Tables.Aggregates.{Table}

  identify(Table, by: :table_id, prefix: "table-")

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
      SitOutParticipant,
      StartRound,
      FinishHand
    ],
    to: Table
  )
end
