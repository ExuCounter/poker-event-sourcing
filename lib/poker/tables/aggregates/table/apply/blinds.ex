defmodule Poker.Tables.Aggregates.Table.Apply.Blinds do
  @moduledoc """
  Applies blind posting events to aggregate state.

  Handles the following events:
  - `SmallBlindPosted` - Deducts small blind from participant
  - `BigBlindPosted` - Deducts big blind from participant
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Aggregates.Table.Helpers
  alias Poker.Tables.Events.{SmallBlindPosted, BigBlindPosted}

  @doc "Deducts small blind from participant chips and updates bets."
  def apply(%Table{} = table, %SmallBlindPosted{} = event) do
    table
    |> Helpers.update_participant(event.participant_id, &%{&1 | chips: &1.chips - event.amount})
    |> Helpers.update_participant_hand(
      event.participant_id,
      &%{&1 | bet_this_round: event.amount, total_bet_this_hand: event.amount}
    )
  end

  # Deducts big blind from participant chips and updates bets.
  def apply(%Table{} = table, %BigBlindPosted{} = event) do
    table
    |> Helpers.update_participant(event.participant_id, &%{&1 | chips: &1.chips - event.amount})
    |> Helpers.update_participant_hand(
      event.participant_id,
      &%{&1 | bet_this_round: event.amount, total_bet_this_hand: event.amount}
    )
  end
end
