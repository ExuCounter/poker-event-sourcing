defmodule Poker.Tables.Aggregates.Table.Handlers.Lifecycle do
  @moduledoc """
  Handles table lifecycle operations: creation, starting, and finishing.
  """

  alias Poker.Tables.Commands.{CreateTable, StartTable, FinishTable, PauseTable, ResumeTable}
  alias Poker.Tables.Events.{TableCreated, TableStarted, TableFinished, TablePaused, TableResumed}
  alias Poker.Tables.Aggregates.Table.Helpers

  @doc """
  Handles table lifecycle commands.
  """
  def handle(_table, %CreateTable{} = command) do
    %TableCreated{
      id: command.table_id,
      creator_id: command.creator_id,
      status: :waiting,
      big_blind: command.settings.big_blind,
      small_blind: command.settings.small_blind,
      starting_stack: command.settings.starting_stack,
      timeout_seconds: command.settings.timeout_seconds,
      table_type: command.settings.table_type
    }
  end

  def handle(%{status: status}, %StartTable{}) when status != :waiting,
    do: {:error, :table_already_started}

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

  def handle(_table, %FinishTable{} = command) do
    %TableFinished{
      table_id: command.table_id,
      reason: command.reason
    }
  end

  # Pause handlers
  def handle(%{status: :finished}, %PauseTable{}),
    do: {:error, :table_finished}

  def handle(%{status: :paused}, %PauseTable{}),
    do: {:error, :already_paused}

  def handle(%{status: :waiting}, %PauseTable{}),
    do: {:error, :table_not_started}

  def handle(table, %PauseTable{} = command) do
    %TablePaused{
      table_id: table.id,
      reason: command.reason
    }
  end

  # Resume handlers
  def handle(%{status: status}, %ResumeTable{}) when status != :paused,
    do: {:error, :table_not_paused}

  def handle(table, %ResumeTable{}) do
    if Helpers.has_participant_not_sitting_out?(table.participants) do
      %TableResumed{table_id: table.id}
    else
      {:error, :no_participants_available}
    end
  end
end
