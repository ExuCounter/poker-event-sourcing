defmodule Poker.Services.HandRank do
  @moduledoc """
  Hand rank encoding/decoding for storage and display.

  Note: Flush hands have suit in second position: {:flush, :h, :A, :K, :J, 7, 5}
  """

  @type hand_rank_tuple ::
          {:straight_flush, atom()}
          | {:four_of_a_kind, atom(), atom()}
          | {:full_house, atom(), atom()}
          | {:flush, atom(), atom(), atom(), atom(), atom(), atom()}
          | {:straight, atom()}
          | {:three_of_a_kind, atom(), atom(), atom()}
          | {:two_pair, atom(), atom(), atom()}
          | {:one_pair, atom(), atom(), atom(), atom()}
          | {:high_card, atom(), atom(), atom(), atom(), atom()}

  @doc """
  Encode hand rank tuple to list for JSON storage.

  ## Examples

      iex> Poker.Services.HandRank.encode({:straight_flush, :A})
      ["straight_flush", "A"]

      iex> Poker.Services.HandRank.encode({:flush, :h, :A, :K, :J, 7, 5})
      ["flush", "h", "A", "K", "J", 7, 5]

      iex> Poker.Services.HandRank.encode({:full_house, :A, :K})
      ["full_house", "A", "K"]
  """
  def encode(hand_rank_tuple) when is_tuple(hand_rank_tuple) do
    hand_rank_tuple
    |> Tuple.to_list()
    |> Enum.map(fn
      int when is_integer(int) -> int
      atom -> Atom.to_string(atom)
    end)
  end

  @doc """
  Convert to detailed display format with kickers.

  ## Examples

      iex> Poker.Services.HandRank.to_display_name({:straight_flush, :A})
      "Royal Flush"

      iex> Poker.Services.HandRank.to_display_name({:straight_flush, :K})
      "Straight Flush, King High"

      iex> Poker.Services.HandRank.to_display_name({:four_of_a_kind, :A, :K})
      "Four Aces"

      iex> Poker.Services.HandRank.to_display_name({:full_house, :A, :K})
      "Full House, Aces over Kings"

      iex> Poker.Services.HandRank.to_display_name({:two_pair, :K, :J, :9})
      "Two Pair, Kings and Jacks"

      iex> Poker.Services.HandRank.to_display_name({:one_pair, :A, :K, :Q, :J})
      "Pair of Aces"
  """
  def to_display_name({:straight_flush, :A}), do: "Royal Flush"

  def to_display_name({:straight_flush, high_card}) do
    "Straight Flush, #{rank_name(high_card)} High"
  end

  def to_display_name({:four_of_a_kind, rank, _kicker}) do
    "Four #{rank_name_plural(rank)}"
  end

  def to_display_name({:full_house, trips, pair}) do
    "Full House, #{rank_name_plural(trips)} over #{rank_name_plural(pair)}"
  end

  def to_display_name({:flush, _suit, high, _, _, _, _}) do
    "Flush, #{rank_name(high)} High"
  end

  def to_display_name({:straight, high_card}) do
    "Straight, #{rank_name(high_card)} High"
  end

  def to_display_name({:three_of_a_kind, rank, _, _}) do
    "Three #{rank_name_plural(rank)}"
  end

  def to_display_name({:two_pair, high_pair, low_pair, _kicker}) do
    "Two Pair, #{rank_name_plural(high_pair)} and #{rank_name_plural(low_pair)}"
  end

  def to_display_name({:one_pair, rank, _, _, _}) do
    "Pair of #{rank_name_plural(rank)}"
  end

  def to_display_name({:high_card, high, _, _, _, _}) do
    "High Card, #{rank_name(high)}"
  end

  # Rank name helpers
  defp rank_name(:A), do: "Ace"
  defp rank_name(:K), do: "King"
  defp rank_name(:Q), do: "Queen"
  defp rank_name(:J), do: "Jack"
  defp rank_name(:T), do: "Ten"
  defp rank_name(10), do: "Ten"
  defp rank_name(9), do: "Nine"
  defp rank_name(8), do: "Eight"
  defp rank_name(7), do: "Seven"
  defp rank_name(6), do: "Six"
  defp rank_name(5), do: "Five"
  defp rank_name(4), do: "Four"
  defp rank_name(3), do: "Three"
  defp rank_name(2), do: "Two"

  defp rank_name_plural(:A), do: "Aces"
  defp rank_name_plural(:K), do: "Kings"
  defp rank_name_plural(:Q), do: "Queens"
  defp rank_name_plural(:J), do: "Jacks"
  defp rank_name_plural(:T), do: "Tens"
  defp rank_name_plural(10), do: "Tens"
  defp rank_name_plural(9), do: "Nines"
  defp rank_name_plural(8), do: "Eights"
  defp rank_name_plural(7), do: "Sevens"
  defp rank_name_plural(6), do: "Sixes"
  defp rank_name_plural(5), do: "Fives"
  defp rank_name_plural(4), do: "Fours"
  defp rank_name_plural(3), do: "Threes"
  defp rank_name_plural(2), do: "Twos"

  @doc """
  Convert to structured map for projections or display.

  Special handling for flush: suit is separated from ranks.

  ## Examples

      iex> Poker.Services.HandRank.to_map({:flush, :h, :A, :K, :J, 7, 5})
      %{
        type: "flush",
        suit: "hearts",
        ranks: ["A", "K", "J", "7", "5"],
        display_name: "Flush"
      }

      iex> Poker.Services.HandRank.to_map({:straight_flush, :A})
      %{
        type: "straight_flush",
        ranks: ["A"],
        display_name: "Straight Flush"
      }
  """
  def to_map({:flush, suit, r1, r2, r3, r4, r5} = hand_rank_tuple) do
    %{
      type: "flush",
      suit: suit_to_string(suit),
      ranks: Enum.map([r1, r2, r3, r4, r5], &to_string/1),
      display_name: to_display_name(hand_rank_tuple)
    }
  end

  def to_map(hand_rank_tuple) do
    [hand_type | ranks] = Tuple.to_list(hand_rank_tuple)

    %{
      type: to_string(hand_type),
      ranks: Enum.map(ranks, &to_string/1),
      display_name: to_display_name(hand_rank_tuple)
    }
  end

  defp suit_to_string(:h), do: "hearts"
  defp suit_to_string(:d), do: "diamonds"
  defp suit_to_string(:c), do: "clubs"
  defp suit_to_string(:s), do: "spades"
  defp suit_to_string(:""), do: ""
end
