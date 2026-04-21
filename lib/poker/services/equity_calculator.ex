defmodule Poker.Services.EquityCalculator do
  @moduledoc """
  Monte Carlo simulation for calculating poker hand equity.

  Calculates win/tie percentages for multiple players based on
  known hole cards and community cards.
  """

  alias Poker.Card
  alias Poker.Services.Comparison

  @default_simulations 1000

  @doc """
  Calculate equity for all players in a hand.

  ## Parameters
    - `player_hands` - List of `{participant_id, hole_cards}` tuples where hole_cards is list of card maps
    - `community_cards` - List of community card maps (0-5 cards)
    - `opts` - Options:
      - `:simulations` - Number of Monte Carlo simulations (default: 1000)

  ## Returns
    Map of participant_id => %{win: float, tie: float}

  ## Example
      iex> EquityCalculator.calculate([
      ...>   {"p1", [%{rank: :A, suit: :hearts}, %{rank: :K, suit: :hearts}]},
      ...>   {"p2", [%{rank: 7, suit: :clubs}, %{rank: 2, suit: :spades}]}
      ...> ], [])
      %{"p1" => %{win: 0.65, tie: 0.01}, "p2" => %{win: 0.34, tie: 0.01}}
  """
  def calculate(player_hands, community_cards, opts \\ []) do
    simulations = Keyword.get(opts, :simulations, @default_simulations)

    # Convert cards to comparison format
    players =
      Enum.map(player_hands, fn {participant_id, hole_cards} ->
        {participant_id, Card.to_comparison_hand(hole_cards)}
      end)

    community = community_cards |> Enum.map(&Card.to_comparison/1)
    cards_needed = 5 - length(community)

    # Get all known cards to exclude from deck
    known_cards = get_known_cards(players, community)
    remaining_deck = build_remaining_deck(known_cards)

    if cards_needed == 0 do
      # All community cards dealt - deterministic result
      calculate_final_equity(players, community)
    else
      # Run Monte Carlo simulation
      run_simulation(players, community, remaining_deck, cards_needed, simulations)
    end
  end

  # When all 5 community cards are known, calculate exact equity
  defp calculate_final_equity(players, community) do
    community_tuple = List.to_tuple(community)

    # Evaluate each player's hand and get value
    hand_values =
      Enum.map(players, fn {participant_id, hole_cards} ->
        {_rank, best_hand} = Comparison.best_hand(hole_cards, community_tuple)
        value = Comparison.hand_value(best_hand)
        {participant_id, value}
      end)

    max_value = hand_values |> Enum.map(&elem(&1, 1)) |> Enum.max()

    winners =
      hand_values
      |> Enum.filter(fn {_id, value} -> value == max_value end)
      |> Enum.map(&elem(&1, 0))

    # Build equity map
    Enum.map(players, fn {participant_id, _} ->
      if participant_id in winners do
        if length(winners) == 1 do
          {participant_id, %{win: 100.0, tie: 0.0}}
        else
          tie_share = 100.0 / length(winners)
          {participant_id, %{win: 0.0, tie: tie_share}}
        end
      else
        {participant_id, %{win: 0.0, tie: 0.0}}
      end
    end)
    |> Map.new()
  end

  # Run Monte Carlo simulation
  defp run_simulation(players, community, remaining_deck, cards_needed, simulations) do
    # Initialize counters
    initial_counts =
      players
      |> Enum.map(fn {id, _} -> {id, %{wins: 0, ties: 0}} end)
      |> Map.new()

    # Run simulations
    final_counts =
      1..simulations
      |> Enum.reduce(initial_counts, fn _, counts ->
        # Draw random cards to complete community
        simulated_community = simulate_community(community, remaining_deck, cards_needed)

        # Determine winner(s)
        winners = determine_winners(players, simulated_community)

        # Update counts
        update_counts(counts, winners)
      end)

    # Convert counts to percentages
    Enum.map(final_counts, fn {participant_id, %{wins: wins, ties: ties}} ->
      {participant_id,
       %{
         win: Float.round(wins / simulations * 100, 1),
         tie: Float.round(ties / simulations * 100, 1)
       }}
    end)
    |> Map.new()
  end

  defp simulate_community(community, remaining_deck, cards_needed) do
    # Randomly select cards_needed cards from remaining deck
    additional_cards =
      remaining_deck
      |> Enum.shuffle()
      |> Enum.take(cards_needed)

    community ++ additional_cards
  end

  defp determine_winners(players, community) do
    community_tuple = List.to_tuple(community)

    # Evaluate each player's hand
    player_values =
      Enum.map(players, fn {participant_id, hole_cards} ->
        {_rank, best_hand} = Comparison.best_hand(hole_cards, community_tuple)
        value = Comparison.hand_value(best_hand)
        {participant_id, value}
      end)

    # Find max value
    max_value = player_values |> Enum.map(&elem(&1, 1)) |> Enum.max()

    # Return all players with max value
    player_values
    |> Enum.filter(fn {_id, value} -> value == max_value end)
    |> Enum.map(&elem(&1, 0))
  end

  defp update_counts(counts, winners) do
    is_tie = length(winners) > 1

    Enum.reduce(winners, counts, fn winner_id, acc ->
      Map.update!(acc, winner_id, fn %{wins: w, ties: t} ->
        if is_tie do
          %{wins: w, ties: t + 1}
        else
          %{wins: w + 1, ties: t}
        end
      end)
    end)
  end

  defp get_known_cards(players, community) do
    player_cards =
      players
      |> Enum.flat_map(fn {_id, hole_cards} -> Tuple.to_list(hole_cards) end)

    player_cards ++ community
  end

  defp build_remaining_deck(known_cards) do
    known_set = MapSet.new(known_cards)

    for rank <- [:A, :K, :Q, :J, :T, 9, 8, 7, 6, 5, 4, 3, 2],
        suit <- [:h, :d, :c, :s],
        card = {rank, suit},
        card not in known_set do
      card
    end
  end
end
