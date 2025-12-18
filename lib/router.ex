defmodule Poker.Router do
  use Commanded.Commands.Router

  alias Poker.Tables.Commands.{
    CreateTable,
    CreateTableSettings,
    JoinTableParticipant,
    StartHand,
    GiveParticipantHand,
    StartTable,
    ParticipantFold,
    ParticipantCheck,
    ParticipantCall,
    ParticipantRaise,
    ParticipantAllIn,
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
      ParticipantFold,
      ParticipantCheck,
      ParticipantCall,
      ParticipantRaise,
      ParticipantAllIn,
      SitInParticipant,
      SitOutParticipant,
      StartRound,
      FinishHand
    ],
    to: Table
  )
end
