defmodule Poker.HandRank do
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
  Encode hand rank tuple to string for storage.

  ## Examples

      iex> Poker.HandRank.encode({:straight_flush, :A})
      "straight_flush:A"

      iex> Poker.HandRank.encode({:flush, :h, :A, :K, :J, 7, 5})
      "flush:h:A:K:J:7:5"

      iex> Poker.HandRank.encode({:full_house, :A, :K})
      "full_house:A:K"
  """
  def encode(hand_rank_tuple) when is_tuple(hand_rank_tuple) do
    hand_rank_tuple
    |> Tuple.to_list()
    |> Enum.map(&to_string/1)
    |> Enum.join(":")
  end

  @doc """
  Decode hand rank string to tuple.

  ## Examples

      iex> Poker.HandRank.decode("straight_flush:A")
      {:straight_flush, :A}

      iex> Poker.HandRank.decode("flush:h:A:K:J:7:5")
      {:flush, :h, :A, :K, :J, 7, 5}

      iex> Poker.HandRank.decode("full_house:A:K")
      {:full_house, :A, :K}
  """
  def decode(hand_rank_string) when is_binary(hand_rank_string) do
    hand_rank_string
    |> String.split(":")
    |> Enum.map(&parse_component/1)
    |> List.to_tuple()
  end

  @doc "Convert to display format"
  def to_display_name({:straight_flush, _}), do: "Straight Flush"
  def to_display_name({:four_of_a_kind, _, _}), do: "Four of a Kind"
  def to_display_name({:full_house, _, _}), do: "Full House"
  def to_display_name({:flush, _, _, _, _, _, _}), do: "Flush"
  def to_display_name({:straight, _}), do: "Straight"
  def to_display_name({:three_of_a_kind, _, _, _}), do: "Three of a Kind"
  def to_display_name({:two_pair, _, _, _}), do: "Two Pair"
  def to_display_name({:one_pair, _, _, _, _}), do: "One Pair"
  def to_display_name({:high_card, _, _, _, _, _}), do: "High Card"

  @doc """
  Convert to structured map for projections or display.

  Special handling for flush: suit is separated from ranks.

  ## Examples

      iex> Poker.HandRank.to_map({:flush, :h, :A, :K, :J, 7, 5})
      %{
        type: "flush",
        suit: "hearts",
        ranks: ["A", "K", "J", "7", "5"],
        display_name: "Flush"
      }

      iex> Poker.HandRank.to_map({:straight_flush, :A})
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

  defp parse_component(component) do
    case Integer.parse(component) do
      {int, ""} -> int
      :error -> String.to_atom(component)
    end
  end

  defp suit_to_string(:h), do: "hearts"
  defp suit_to_string(:d), do: "diamonds"
  defp suit_to_string(:c), do: "clubs"
  defp suit_to_string(:s), do: "spades"
  defp suit_to_string(:""), do: ""
end
