defmodule Poker.Services.HandEvaluatorStub do
  @behaviour Poker.Services.HandEvaluator.Behaviour

  alias Poker.{Card, HandRank}

  @impl true
  def determine_winners(participant_hands, community_cards) do
    community_cards = Card.to_comparison_hand(community_cards)

    values =
      participant_hands
      |> Enum.map(fn hand ->
        hole_cards = hand |> Map.get(:hole_cards) |> then(&Card.to_comparison_hand/1)

        {hand_rank, best_hand} = Poker.Comparison.best_hand(hole_cards, community_cards)

        hand_value = Poker.Comparison.hand_value(best_hand)

        %{
          participant_id: hand.participant_id,
          hole_cards: hand.hole_cards,
          hand_rank: HandRank.encode(hand_rank),
          hand_value: hand_value
        }
      end)
      |> Enum.sort_by(& &1.hand_value, :desc)

    max_value = values |> hd() |> Map.get(:hand_value)

    values
    |> Enum.take_while(&(&1.hand_value == max_value))
    |> Enum.map(&Map.drop(&1, [:hand_value]))
  end
end
