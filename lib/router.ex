defmodule Poker.Router do
  use Commanded.Commands.Router

  alias Poker.Tables.Commands.{
    CreateTable,
    CreateTableSettings,
    JoinTableParticipant,
    StartHand,
    StartTable,
    ParticipantFold,
    ParticipantCheck,
    ParticipantCall,
    ParticipantRaise,
    ParticipantAllIn,
    SitInParticipant,
    SitOutParticipant,
    StartRound,
    FinishHand,
    TimeoutParticipant,
    ResumeTable,
    PauseTable
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
      ParticipantFold,
      ParticipantCheck,
      ParticipantCall,
      ParticipantRaise,
      ParticipantAllIn,
      SitInParticipant,
      SitOutParticipant,
      StartRound,
      FinishHand,
      TimeoutParticipant,
      ResumeTable,
      PauseTable
    ],
    to: Table
  )
end
