defmodule Poker.Tables.Aggregates.Table.Apply.Hand do
  @moduledoc """
  Handles hand event application.
  """

  alias Poker.Tables.Aggregates.Table

  alias Poker.Tables.Events.{
    HandStarted,
    HandFinished,
    ParticipantHandGiven,
    ParticipantShowdownCardsRevealed,
    PayoutDistributed
  }

  def apply(%Table{} = table, %HandStarted{} = event) do
    hand = %{id: event.id}

    table
    |> Map.put(:hand, hand)
    |> Map.put(:community_cards, [])
    |> Map.put(:participant_hands, [])
    |> Map.put(:round, nil)
    |> Map.put(:pots, [])
    |> Map.put(:remaining_deck, nil)
    |> Map.put(:payouts, [])
    |> Map.put(:revealed_cards, %{})
  end

  def apply(%Table{participant_hands: participant_hands} = table, %ParticipantHandGiven{} = event) do
    new_participant_hand = %{
      id: event.id,
      participant_id: event.participant_id,
      hole_cards: event.hole_cards,
      position: event.position,
      status: event.status,
      bet_this_round: event.bet_this_round,
      total_bet_this_hand: event.total_bet_this_hand
    }

    %Table{table | participant_hands: participant_hands ++ [new_participant_hand]}
  end

  def apply(
        %Table{} = table,
        %ParticipantShowdownCardsRevealed{
          participant_id: participant_id,
          hole_cards: hole_cards
        } = event
      ) do
    revealed_cards = Map.get(table, :revealed_cards, %{})
    updated_revealed_cards = Map.put(revealed_cards, participant_id, hole_cards)

    Map.put(table, :revealed_cards, updated_revealed_cards)
  end

  def apply(%Table{participants: participants, payouts: payouts} = table, %PayoutDistributed{} = event) do
    updated_participants =
      Enum.map(participants, fn participant ->
        if participant.id == event.participant_id do
          %{participant | chips: participant.chips + event.amount}
        else
          participant
        end
      end)

    # Build payout map to append to aggregate payouts
    payout = %{
      pot_id: event.pot_id,
      participant_id: event.participant_id,
      amount: event.amount,
      hand_rank: event.hand_rank
    }

    %Table{
      table
      | participants: updated_participants,
        payouts: (payouts || []) ++ [payout]
    }
  end

  def apply(%Table{} = table, %HandFinished{}) do
    # Chips already updated by PayoutDistributed events
    # HandFinished just marks hand as complete
    table
  end
end
