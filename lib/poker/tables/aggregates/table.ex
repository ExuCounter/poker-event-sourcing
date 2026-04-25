defmodule Poker.Tables.Aggregates.Table do
  @moduledoc """
  Main aggregate for poker table.
  Delegates command handling to specialized submodules.
  """

  # Submodules
  alias Poker.Tables.Aggregates.Table.{Handlers, Apply}

  alias Poker.Tables.Commands.{
    CreateTable,
    JoinTableParticipant,
    StartHand,
    StartTable,
    ParticipantFold,
    ParticipantCheck,
    ParticipantCall,
    ParticipantRaise,
    ParticipantAllIn,
    SitOutParticipant,
    SitInParticipant,
    BuyInParticipant,
    StartRound,
    FinishHand,
    FinishTable,
    TimeoutParticipant,
    PauseTable,
    ResumeTable,
    LeaveTable,
    UpdateTableBlinds
  }

  alias Poker.Tables.Events.{
    TableCreated,
    ParticipantJoined,
    HandStarted,
    ParticipantHandGiven,
    TableStarted,
    ParticipantFolded,
    ParticipantChecked,
    ParticipantCalled,
    ParticipantRaised,
    ParticipantWentAllIn,
    ParticipantSatOut,
    ParticipantSatIn,
    ParticipantBoughtIn,
    ParticipantBuyInApplied,
    SmallBlindPosted,
    BigBlindPosted,
    RoundStarted,
    RoundCompleted,
    PotsRecalculated,
    DeckGenerated,
    DeckUpdated,
    ParticipantToActSelected,
    DealerButtonMoved,
    HandFinished,
    TableFinished,
    ParticipantBusted,
    ParticipantLeft,
    ParticipantShowdownCardsRevealed,
    PayoutDistributed,
    ParticipantTimedOut,
    TablePaused,
    TableResumed,
    TableBlindsUpdated
  }

  defstruct [
    :id,
    :creator_id,
    :status,
    :game_mode,
    :source_id,
    :settings,
    :participants,
    :hand,
    :round,
    :community_cards,
    :pots,
    :participant_hands,
    :remaining_deck,
    :dealer_button_id,
    :payouts
  ]

  # COMMAND HANDLERS

  def execute(table, %cmd{} = command)
      when cmd in [CreateTable, StartTable, FinishTable, PauseTable, ResumeTable, UpdateTableBlinds] do
    Handlers.Lifecycle.handle(table, command)
  end

  def execute(table, %cmd{} = command)
      when cmd in [
             JoinTableParticipant,
             ParticipantFold,
             ParticipantCheck,
             ParticipantCall,
             ParticipantRaise,
             ParticipantAllIn,
             TimeoutParticipant,
             SitOutParticipant,
             SitInParticipant,
             BuyInParticipant,
             LeaveTable
           ] do
    Handlers.Participants.handle(table, command)
  end

  def execute(table, %cmd{} = command)
      when cmd in [StartHand, FinishHand] do
    Handlers.Hand.handle(table, command)
  end

  def execute(table, %StartRound{} = command),
    do: Handlers.Round.handle(table, command)

  # STATE MUTATORS - Delegate to Apply modules

  def apply(table, %evt{} = event)
      when evt in [TableCreated, TableStarted, TableFinished, TablePaused, TableResumed, TableBlindsUpdated] do
    Apply.Lifecycle.apply(table, event)
  end

  def apply(table, %evt{} = event)
      when evt in [
             ParticipantJoined,
             ParticipantSatOut,
             ParticipantSatIn,
             ParticipantBoughtIn,
             ParticipantBuyInApplied,
             ParticipantBusted,
             ParticipantLeft,
             ParticipantFolded,
             ParticipantChecked,
             ParticipantCalled,
             ParticipantRaised,
             ParticipantWentAllIn,
             ParticipantToActSelected,
             ParticipantTimedOut
           ] do
    Apply.Participants.apply(table, event)
  end

  def apply(table, %evt{} = event)
      when evt in [
             HandStarted,
             ParticipantHandGiven,
             ParticipantShowdownCardsRevealed,
             HandFinished,
             PayoutDistributed
           ] do
    Apply.Hand.apply(table, event)
  end

  def apply(table, %evt{} = event)
      when evt in [RoundStarted, RoundCompleted] do
    Apply.Round.apply(table, event)
  end

  def apply(table, %evt{} = event)
      when evt in [SmallBlindPosted, BigBlindPosted] do
    Apply.Blinds.apply(table, event)
  end

  def apply(table, %evt{} = event)
      when evt in [DeckGenerated, DeckUpdated, DealerButtonMoved] do
    Apply.Deck.apply(table, event)
  end

  def apply(table, %PotsRecalculated{} = event)
      when is_struct(event, PotsRecalculated) do
    Apply.Pot.apply(table, event)
  end
end
