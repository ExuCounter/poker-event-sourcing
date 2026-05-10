# Source: https://github.com/wojtekmach/poker_elixir/blob/master/lib/poker.ex
# License: MIT License
# Copyright (c) 2015-2024 Wojtek Mach
#
# This module using the same namespace as our app, so we need to rename it to avoid conflicts.

defmodule Poker.Services.Comparison do
  @moduledoc """
  An Elixir library to work with Poker hands.

  Source: <https://github.com/wojtekmach/poker_elixir>

  Documentation: <http://hexdocs.pm/poker/>

  ## Example

  ```elixir
  hand1 = "As Ks Qs Js Ts"
  hand2 = "Ac Ad Ah As Kc"

  Poker.hand_rank(hand1) # => {:straight_flush, :A}
  Poker.hand_rank(hand2) # => {:four_of_a_kind, :A, :K}

  Poker.hand_compare(hand1, hand2) # => :gt
  ```
  """

  @doc """
  Returns the best rank & hand out of hole cards and community cards.

      iex> Poker.best_hand("4c 5d", "3c 6c 7d Ad Ac")
      {{:straight, 7}, {{7,:d}, {6,:c}, {5,:d}, {4,:c}, {3,:c}}}
  """
  def best_hand(hole_cards, community_cards) when is_binary(hole_cards) do
    best_hand(parse_hand(hole_cards), community_cards)
  end

  def best_hand(hole_cards, community_cards) when is_binary(community_cards) do
    best_hand(hole_cards, parse_hand(community_cards))
  end

  def best_hand(hole_cards, community_cards) do
    hole_cards = Tuple.to_list(hole_cards)
    community_cards = Tuple.to_list(community_cards)

    cards = hole_cards ++ community_cards
    total_cards = length(cards)

    cond do
      # Not enough cards for any evaluation
      total_cards < 2 ->
        {nil, nil}

      # Full hand evaluation (5+ cards)
      total_cards >= 5 ->
        hand =
          comb(5, cards)
          |> Enum.sort_by(fn cards ->
            cards |> List.to_tuple() |> hand_value
          end)
          |> Enum.reverse()
          |> hd
          |> List.to_tuple()

        {hand_rank(hand), sort_hand(hand)}

      # Pre-flop or early streets: evaluate available cards
      true ->
        evaluate_partial_hand(cards)
    end
  end

  # Evaluate hands with fewer than 5 cards (pre-flop, flop with 4 cards, etc.)
  defp evaluate_partial_hand(cards) do
    sorted_cards = Enum.sort_by(cards, fn {rank, _} -> card_value(rank) end, :desc)
    rank_counts = Enum.frequencies_by(cards, fn {rank, _} -> rank end)

    # Find pairs, trips, etc.
    groups =
      rank_counts
      |> Enum.sort_by(fn {rank, count} -> {count, card_value(rank)} end, :desc)
      |> Enum.map(fn {rank, count} -> {count, rank} end)

    hand_tuple = List.to_tuple(sorted_cards)

    case groups do
      # Four of a kind (rare with < 5 cards but possible with 4)
      [{4, rank} | _] ->
        kicker = sorted_cards |> Enum.find(fn {r, _} -> r != rank end)
        kicker_rank = if kicker, do: elem(kicker, 0), else: rank
        {{:four_of_a_kind, rank, kicker_rank}, hand_tuple}

      # Three of a kind
      [{3, rank} | rest] ->
        kickers = Enum.filter(sorted_cards, fn {r, _} -> r != rank end)

        {k1, k2} =
          case kickers do
            [{r1, _}, {r2, _} | _] -> {r1, r2}
            [{r1, _}] -> {r1, r1}
            [] -> {rank, rank}
          end

        {{:three_of_a_kind, rank, k1, k2}, hand_tuple}

      # Two pair
      [{2, rank1}, {2, rank2} | _] ->
        [high, low] = Enum.sort([rank1, rank2], &(card_value(&1) >= card_value(&2)))
        kicker = sorted_cards |> Enum.find(fn {r, _} -> r != rank1 and r != rank2 end)
        kicker_rank = if kicker, do: elem(kicker, 0), else: high
        {{:two_pair, high, low, kicker_rank}, hand_tuple}

      # One pair
      [{2, rank} | _] ->
        kickers = Enum.filter(sorted_cards, fn {r, _} -> r != rank end)

        {k1, k2, k3} =
          case kickers do
            [{r1, _}, {r2, _}, {r3, _} | _] -> {r1, r2, r3}
            [{r1, _}, {r2, _}] -> {r1, r2, r2}
            [{r1, _}] -> {r1, r1, r1}
            [] -> {rank, rank, rank}
          end

        {{:one_pair, rank, k1, k2, k3}, hand_tuple}

      # High card
      _ ->
        ranks = Enum.map(sorted_cards, fn {rank, _} -> rank end)

        {r1, r2, r3, r4, r5} =
          case ranks do
            [a, b, c, d, e | _] -> {a, b, c, d, e}
            [a, b, c, d] -> {a, b, c, d, d}
            [a, b, c] -> {a, b, c, c, c}
            [a, b] -> {a, b, b, b, b}
            [a] -> {a, a, a, a, a}
          end

        {{:high_card, r1, r2, r3, r4, r5}, hand_tuple}
    end
  end

  defp comb(0, _), do: [[]]
  defp comb(_, []), do: []

  defp comb(m, [h | t]) do
    for(l <- comb(m - 1, t), do: [h | l]) ++ comb(m, t)
  end

  @doc """
  Compares two poker hands and returns :gt, :eq or :lt when the first hand is respectively more valuable, equally valuable or less valuable than the second hand.

      iex> Poker.hand_compare("Ac Qd Ah As Kc", "Ac Ad Ah Kc Kc")
      :lt
  """
  def hand_compare(hand1, hand2) when is_binary(hand1) do
    hand_compare(parse_hand(hand1), hand2)
  end

  def hand_compare(hand1, hand2) when is_binary(hand2) do
    hand_compare(hand1, parse_hand(hand2))
  end

  def hand_compare(hand1, hand2) do
    r = hand_value(hand1) - hand_value(hand2)

    cond do
      r > 0 -> :gt
      r == 0 -> :eq
      r < 0 -> :lt
    end
  end

  @doc """
  Returns hand value - a number than uniquely identifies a given hand.
  The bigger the number the more valuable a given hand is.

      iex> Poker.hand_value("Ac Kc Qc Jc Tc")
      8014
  """
  def hand_value(str) when is_binary(str) do
    str |> parse_hand |> hand_value
  end

  def hand_value(hand) do
    case hand_rank(hand) do
      {:straight_flush, a} ->
        8_000 + card_value(a)

      {:four_of_a_kind, a, b} ->
        7_000 + 15 * card_value(a) + card_value(b)

      {:full_house, a, b} ->
        6_000 + 15 * card_value(a) + card_value(b)

      {:flush, _r, a, b, c, d, e} ->
        5_000 + card_value(a) + card_value(b) + card_value(c) + card_value(d) + card_value(e)

      {:straight, a} ->
        4_000 + card_value(a)

      {:three_of_a_kind, a, b, c} ->
        3_000 + 15 * card_value(a) + card_value(b) + card_value(c)

      {:two_pair, a, b, c} ->
        2_000 + 15 * card_value(a) + 15 * card_value(b) + card_value(c)

      {:one_pair, a, b, c, d} ->
        1_000 + 15 * card_value(a) + card_value(b) + card_value(c) + card_value(d)

      {:high_card, a, b, c, d, e} ->
        card_value(a) + card_value(b) + card_value(c) + card_value(d) + card_value(e)
    end
  end

  @doc """
  Returns rank of a given hand.

      iex> Poker.hand_rank("Ac Kc Qc Jc Tc")
      {:straight_flush, :A}

      iex> Poker.hand_rank("Kc Qc Jc Tc 9c")
      {:straight_flush, :K}

      iex> Poker.hand_rank("5c 4c 3c 2c Ac")
      {:straight_flush, 5}

      iex> Poker.hand_rank("Ac Ad Ah As Kd")
      {:four_of_a_kind, :A, :K}

      iex> Poker.hand_rank("Ac Ad Ah Kc Kd")
      {:full_house, :A, :K}

      iex> Poker.hand_rank("Kc Kd Kh Ac Ad")
      {:full_house, :K, :A}

      iex> Poker.hand_rank("Ac Qc Jc Tc 9c")
      {:flush, :c, :A, :Q, :J, :T, 9}

      iex> Poker.hand_rank("Ac Kc Qc Jc Td")
      {:straight, :A}

      iex> Poker.hand_rank("Kc Qc Jc Tc 9d")
      {:straight, :K}

      iex> Poker.hand_rank("5c 4c 3c 2c Ad")
      {:straight, 5}

      iex> Poker.hand_rank("Ac Ad Ah Kc Qc")
      {:three_of_a_kind, :A, :K, :Q}

      iex> Poker.hand_rank("Ac Ad Kc Kd Qc")
      {:two_pair, :A, :K, :Q}

      iex> Poker.hand_rank("Ac Ad Kc Qc Jd")
      {:one_pair, :A, :K, :Q, :J}

      iex> Poker.hand_rank("Ac Qc Jd Td 9c")
      {:high_card, :A, :Q, :J, :T, 9}
  """
  def hand_rank(str) when is_binary(str) do
    parse_hand(str) |> hand_rank
  end

  def hand_rank(hand) do
    unless length(Tuple.to_list(hand)) == 5 do
      raise ArgumentError, "Must pass 5 cards, got: #{inspect(hand)}"
    end

    hand = sort_hand(hand)

    if is_straight(hand) do
      {{r1, _}, {r2, _}, _, _, _} = hand

      r =
        if r1 == :A && r2 == 5 do
          5
        else
          r1
        end

      if is_flush(hand) do
        {:straight_flush, r}
      else
        {:straight, r}
      end
    else
      case hand do
        {{a, _}, {a, _}, {a, _}, {a, _}, {b, _}} -> {:four_of_a_kind, a, b}
        {{a, _}, {a, _}, {a, _}, {b, _}, {b, _}} -> {:full_house, a, b}
        {{a, _}, {a, _}, {b, _}, {b, _}, {b, _}} -> {:full_house, b, a}
        {{r1, a}, {r2, a}, {r3, a}, {r4, a}, {r5, a}} -> {:flush, a, r1, r2, r3, r4, r5}
        {{a, _}, {a, _}, {a, _}, {b, _}, {c, _}} -> {:three_of_a_kind, a, b, c}
        {{a, _}, {a, _}, {b, _}, {b, _}, {c, _}} -> {:two_pair, a, b, c}
        {{a, _}, {a, _}, {b, _}, {c, _}, {d, _}} -> {:one_pair, a, b, c, d}
        {{a, _}, {b, _}, {c, _}, {d, _}, {e, _}} -> {:high_card, a, b, c, d, e}
      end
    end
  end

  defp is_straight(str) when is_binary(str) do
    str |> parse_hand |> is_straight
  end

  defp is_straight({{a, _}, {b, _}, {c, _}, {d, _}, {e, _}}) do
    (card_value(a) == card_value(b) + 1 || (a == :A && b == 5)) &&
      card_value(b) == card_value(c) + 1 &&
      card_value(c) == card_value(d) + 1 &&
      card_value(d) == card_value(e) + 1
  end

  defp is_flush({{_, a}, {_, a}, {_, a}, {_, a}, {_, a}}), do: true
  defp is_flush({_, _, _, _, _}), do: false

  defp card_value(:A), do: 14
  defp card_value(:K), do: 13
  defp card_value(:Q), do: 12
  defp card_value(:J), do: 11
  defp card_value(:T), do: 10
  defp card_value("A"), do: 14
  defp card_value("K"), do: 13
  defp card_value("Q"), do: 12
  defp card_value("J"), do: 11
  defp card_value("T"), do: 10
  defp card_value(i) when is_integer(i) and i >= 2 and i <= 9, do: i

  @doc """
  Accepts a string and returns a tuple of cards. A card is a tuple of rank and suit.

      iex> Poker.parse_hand("Ac Kd")
      {{:A, :c}, {:K, :d}}
  """
  def parse_hand(str) do
    str
    |> String.split(" ")
    |> Enum.map(&parse_card/1)
    |> List.to_tuple()
  end

  defp parse_card(str) do
    [rank, suit] = String.codepoints(str)
    {parse_rank(rank), String.to_atom(suit)}
  end

  defp parse_rank("A"), do: :A
  defp parse_rank("K"), do: :K
  defp parse_rank("Q"), do: :Q
  defp parse_rank("J"), do: :J
  defp parse_rank("T"), do: :T
  defp parse_rank(str), do: String.to_integer(str)

  defp sort_hand(hand) do
    cards = Tuple.to_list(hand)

    # Count occurrences of each rank
    rank_counts =
      cards
      |> Enum.frequencies_by(fn {rank, _} -> rank end)

    # Sort by: 1) frequency descending, 2) card value descending
    # This ensures pairs/trips/quads are grouped at the front
    cards
    |> Enum.sort_by(fn {rank, _} -> {rank_counts[rank], card_value(rank)} end)
    |> Enum.reverse()
    |> List.to_tuple()
  end
end
