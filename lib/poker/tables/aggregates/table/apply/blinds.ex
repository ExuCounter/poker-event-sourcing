defmodule Poker.Tables.Aggregates.Table.Apply.Blinds do
  @moduledoc """
  Handles blind posting event application.
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Aggregates.Table.Helpers
  alias Poker.Tables.Events.{SmallBlindPosted, BigBlindPosted}

  def apply(%Table{} = table, %SmallBlindPosted{} = event) do
    table
    |> Helpers.update_participant(event.participant_id, &%{&1 | chips: &1.chips - event.amount})
    |> Helpers.update_participant_hand(
      event.participant_id,
      &%{&1 | bet_this_round: event.amount, total_bet_this_hand: event.amount}
    )
  end

  def apply(%Table{} = table, %BigBlindPosted{} = event) do
    table
    |> Helpers.update_participant(event.participant_id, &%{&1 | chips: &1.chips - event.amount})
    |> Helpers.update_participant_hand(
      event.participant_id,
      &%{&1 | bet_this_round: event.amount, total_bet_this_hand: event.amount}
    )
  end
end
