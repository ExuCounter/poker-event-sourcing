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
    PauseTable,
    LeaveTable
  }

  alias Poker.Wallet.Commands.{
    CreateWallet,
    DepositFunds,
    ReserveFunds,
    ReleaseFunds
  }

  alias Poker.CashGames.Commands.{
    CreateCashGame,
    CloseCashGame
  }

  alias Poker.Tables.Aggregates.Table
  alias Poker.Wallet.Aggregates.Wallet
  alias Poker.CashGames.Aggregates.CashGame

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
      PauseTable,
      LeaveTable
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

  # CashGame aggregate - identified by cash_game_id
  identify(CashGame, by: :cash_game_id, prefix: "cash-game-")

  dispatch(
    [
      CreateCashGame,
      CloseCashGame
    ],
    to: CashGame
  )
end
