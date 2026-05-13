defmodule Poker.Tables.Aggregates.Table.Apply.Lifecycle do
  @moduledoc """
  Applies table lifecycle events to aggregate state.

  Handles the following events:
  - `TableCreated` - Initializes a new table with settings and empty participants
  - `TableStarted` - Transitions table to live status
  - `TableFinished` - Marks table as finished
  - `TablePaused` - Pauses the table (e.g., when all players sit out)
  - `TableResumed` - Resumes a paused table
  """

  alias Poker.Tables.Aggregates.Table

  alias Poker.Tables.Events.{
    TableCreated,
    TableStarted,
    TableFinished,
    TablePaused,
    TableResumed,
    TableBlindsUpdated
  }

  @doc "Initializes table state from creation event."
  def apply(%Table{} = _table, %TableCreated{} = created) do
    settings = %{
      small_blind: created.small_blind,
      big_blind: created.big_blind,
      starting_stack: created.starting_stack,
      timeout_seconds: created.timeout_seconds,
      table_type: created.table_type
    }

    %Table{
      id: created.id,
      creator_id: created.creator_id,
      status: created.status,
      game_mode: created.game_mode,
      source_id: created.source_id,
      settings: settings,
      participants: [],
      hand: nil,
      round: nil,
      participant_hands: []
    }
  end

  # Updates table status to live.
  def apply(%Table{} = table, %TableStarted{} = event) do
    %Table{table | status: event.status}
  end

  # Marks table as finished.
  def apply(%Table{} = table, %TableFinished{}) do
    %Table{table | status: :finished}
  end

  # Pauses the table.
  def apply(%Table{} = table, %TablePaused{}) do
    %Table{table | status: :paused}
  end

  # Resumes a paused table.
  def apply(%Table{} = table, %TableResumed{}) do
    %Table{table | status: :live}
  end

  # Updates blind levels (tournament blind advancement).
  def apply(%Table{settings: settings} = table, %TableBlindsUpdated{} = event) do
    %Table{
      table
      | settings: %{settings | small_blind: event.small_blind, big_blind: event.big_blind}
    }
  end
end
