defmodule Poker.Tables.Aggregates.Table.Handlers.Lifecycle do
  @moduledoc """
  Handles table lifecycle commands.

  This module processes the following commands:
  - `CreateTable` - Creates a new table with settings
  - `StartTable` - Starts the table (requires 2+ participants)
  - `FinishTable` - Ends the table
  - `PauseTable` - Pauses a live table
  - `ResumeTable` - Resumes a paused table

  ## Validation Rules
  - Tables can only be started from waiting status
  - Tables require at least 2 participants to start
  - Pausing requires a live table
  - Resuming requires a paused table with available participants
  """

  alias Poker.Tables.Commands.{CreateTable, StartTable, FinishTable, PauseTable, ResumeTable, UpdateTableBlinds}
  alias Poker.Tables.Events.{TableCreated, TableStarted, TableFinished, TablePaused, TableResumed, TableBlindsUpdated}
  alias Poker.Tables.Aggregates.Table.Helpers

  # =============================================================================
  # CREATE TABLE
  # =============================================================================

  @doc "Creates a new table with the specified settings."
  def handle(_table, %CreateTable{} = command) do
    # All tables start as waiting until they have enough players
    %TableCreated{
      id: command.table_id,
      creator_id: command.creator_id,
      status: :waiting,
      game_mode: command.game_mode,
      big_blind: command.settings.big_blind,
      small_blind: command.settings.small_blind,
      starting_stack: command.settings.starting_stack,
      timeout_seconds: command.settings.timeout_seconds,
      table_type: command.settings.table_type,
      source_id: command.source_id
    }
  end

  # =============================================================================
  # START TABLE
  # =============================================================================

  def handle(%{status: status}, %StartTable{}) when status != :waiting,
    do: {:error, :table_already_started}

  # Starts the table if there are enough participants.
  def handle(%{participants: participants} = table, %StartTable{}) do
    if length(participants) >= 2 do
      %TableStarted{
        id: table.id,
        status: :live
      }
    else
      {:error, :not_enough_participants}
    end
  end

  # =============================================================================
  # FINISH TABLE
  # =============================================================================

  # Finishes the table with the given reason.
  def handle(_table, %FinishTable{} = command) do
    %TableFinished{
      table_id: command.table_id,
      reason: command.reason
    }
  end

  # =============================================================================
  # PAUSE TABLE
  # =============================================================================

  def handle(%{status: :finished}, %PauseTable{}),
    do: {:error, :table_finished}

  def handle(%{status: :paused}, %PauseTable{}),
    do: {:error, :already_paused}

  def handle(%{status: :waiting}, %PauseTable{}),
    do: {:error, :table_not_started}

  # Pauses a live table.
  def handle(table, %PauseTable{} = command) do
    %TablePaused{
      table_id: table.id,
      reason: command.reason
    }
  end

  # =============================================================================
  # RESUME TABLE
  # =============================================================================

  def handle(%{status: status}, %ResumeTable{}) when status != :paused,
    do: {:error, :table_not_paused}

  # Resumes a paused table if participants are available.
  def handle(table, %ResumeTable{}) do
    if Helpers.has_participant_not_sitting_out?(table.participants) do
      %TableResumed{table_id: table.id}
    else
      {:error, :no_participants_available}
    end
  end

  # =============================================================================
  # UPDATE TABLE BLINDS (tournament blind level advancement)
  # =============================================================================

  def handle(%{game_mode: :tournament, status: status}, %UpdateTableBlinds{} = cmd)
      when status in [:live, :paused] do
    %TableBlindsUpdated{
      table_id: cmd.table_id,
      small_blind: cmd.small_blind,
      big_blind: cmd.big_blind
    }
  end

  def handle(%{game_mode: mode}, %UpdateTableBlinds{}) when mode != :tournament,
    do: {:error, :not_a_tournament}

  def handle(_table, %UpdateTableBlinds{}),
    do: {:error, :table_not_live}
end
