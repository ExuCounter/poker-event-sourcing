defmodule Poker.Tables.Aggregates.Table.Apply.Hand do
  @moduledoc """
  Handles hand event application.
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Events.{HandStarted, HandFinished, ParticipantHandGiven}

  def apply(%Table{} = table, %HandStarted{} = event) do
    hand = %{id: event.id}

    %Table{
      table
      | hand: hand,
        community_cards: [],
        participant_hands: [],
        round: nil,
        pots: [],
        remaining_deck: nil
    }
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

  def apply(%Table{} = table, %HandFinished{payouts: payouts}) do
    updated_participants =
      Enum.map(table.participants, fn participant ->
        total_payout =
          payouts
          |> Enum.filter(&(&1.participant_id == participant.id))
          |> Enum.sum_by(& &1.amount)

        %{participant | chips: participant.chips + total_payout}
      end)

    %Table{
      table
      | participants: updated_participants,
        community_cards: [],
        participant_hands: [],
        round: nil,
        pots: [],
        remaining_deck: nil
    }
  end
end
