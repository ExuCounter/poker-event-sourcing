defmodule Poker.Tables.Aggregates.Table.Handlers.Lifecycle do
  @moduledoc """
  Handles table lifecycle operations: creation, starting, and finishing.
  """

  alias Poker.Tables.Commands.{CreateTable, StartTable, FinishTable}
  alias Poker.Tables.Events.{TableCreated, TableStarted, TableFinished}

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
end
