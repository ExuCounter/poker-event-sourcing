defmodule Poker.Services.HandEvaluator.Implementation do
  @behaviour Poker.Services.HandEvaluator.Behaviour

  @impl true
  def determine_winners(participant_hands, community_cards) do
    community_cards = cast(community_cards)

    values =
      participant_hands
      |> Enum.map(fn hand ->
        hole_cards = hand |> Map.get(:hole_cards) |> cast()

        {hand_rank, best_hand} = Poker.Comparison.best_hand(hole_cards, community_cards)

        hand_value = Poker.Comparison.hand_value(best_hand)

        %{
          participant_id: hand.participant_id,
          hole_cards: hand.hole_cards,
          hand_rank: hand_rank |> Tuple.to_list(),
          hand_value: hand_value
        }
      end)
      |> Enum.sort_by(& &1.hand_value, :desc)

    max_value = values |> hd() |> Map.get(:hand_value)

    values
    |> Enum.take_while(&(&1.hand_value == max_value))
    |> Enum.map(&Map.drop(&1, [:hand_value]))
  end

  defp cast(cards) when is_list(cards) do
    Enum.map(cards, &cast/1) |> List.to_tuple()
  end

  defp load(cards) when is_list(cards) do
    Enum.map(cards, &load/1)
  end

  defp cast(card) do
    {card.rank, suit_abbreviation(card.suit)}
  end

  defp load(card) do
    {card.rank, suit_full(card.suit)}
  end

  defp suit_abbreviation(suit) do
    %{hearts: :h, diamonds: :d, clubs: :c, spades: :s} |> Map.get(suit)
  end

  defp suit_full(suit_abbr) do
    %{h: :hearts, d: :diamonds, c: :clubs, s: :spades} |> Map.get(suit_abbr)
  end
end
