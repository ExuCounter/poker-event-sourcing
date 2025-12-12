defmodule Poker.Tables.Aggregates.Table.Apply.Lifecycle do
  @moduledoc """
  Handles table lifecycle event application (creation, start, finish).
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Events.{TableCreated, TableStarted, TableFinished}

  def apply(%Table{} = table, %TableCreated{} = created) do
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
      settings: settings,
      participants: [],
      hand: nil,
      round: nil,
      participant_hands: []
    }
  end

  def apply(%Table{} = table, %TableStarted{} = event) do
    %Table{table | status: event.status}
  end

  def apply(%Table{} = table, %TableFinished{}) do
    %Table{table | status: :finished}
  end
end
