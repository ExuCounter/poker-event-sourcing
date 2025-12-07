defmodule Poker.Tables.Aggregates.Table.Apply.Blinds do
  @moduledoc """
  Handles blind posting event application.
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Aggregates.Table.Helpers
  alias Poker.Tables.Events.{SmallBlindPosted, BigBlindPosted}

  def apply(%Table{} = table, %SmallBlindPosted{} = event) do
    updated_participants =
      Helpers.update_participant(
        table,
        event.participant_id,
        &%{
          &1
          | chips: &1.chips - event.amount,
            bet_this_round: event.amount,
            total_bet_this_hand: event.amount
        }
      )

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{} = table, %BigBlindPosted{} = event) do
    updated_participants =
      Helpers.update_participant(
        table,
        event.participant_id,
        &%{
          &1
          | chips: &1.chips - event.amount,
            bet_this_round: event.amount,
            total_bet_this_hand: event.amount
        }
      )

    %Table{table | participants: updated_participants}
  end
end
