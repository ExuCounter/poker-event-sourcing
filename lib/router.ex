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

  alias Poker.Wallet.Commands.{
    CreateWallet,
    DepositFunds,
    ReserveFunds,
    ReleaseFunds
  }

  alias Poker.Tables.Aggregates.Table
  alias Poker.Wallet.Aggregates.Wallet

  # Table aggregate - identified by table_id
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

  # Wallet aggregate - identified by player_id
  identify(Wallet, by: :player_id, prefix: "wallet-")

  dispatch(
    [
      CreateWallet,
      DepositFunds,
      ReserveFunds,
      ReleaseFunds
    ],
    to: Wallet
  )
end
