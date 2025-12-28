defmodule Poker.Card do
  @moduledoc """
  Card representation and conversion utilities.

  Supports two formats:
  - Domain format: %{rank: :A | integer, suit: :hearts | :diamonds | :clubs | :spades}
  - Comparison format: {:A | integer, :h | :d | :c | :s} (tuple for Poker.Comparison)
  """

  @type domain_card :: %{rank: rank(), suit: suit()}
  @type comparison_card :: {rank(), suit_abbrev()}

  @type rank :: :A | :K | :Q | :J | :T | 2..9
  @type suit :: :hearts | :diamonds | :clubs | :spades
  @type suit_abbrev :: :h | :d | :c | :s

  @suit_map %{
    hearts: :h,
    diamonds: :d,
    clubs: :c,
    spades: :s
  }

  @suit_reverse_map Map.new(@suit_map, fn {k, v} -> {v, k} end)

  @doc "Convert domain card to comparison format"
  def to_comparison(%{rank: rank, suit: suit}) do
    {rank, @suit_map[suit]}
  end

  @doc "Convert comparison card to domain format"
  def to_domain({rank, suit_abbrev}) do
    %{rank: rank, suit: @suit_reverse_map[suit_abbrev]}
  end

  @doc "Convert list of domain cards to comparison tuple"
  def to_comparison_hand(cards) when is_list(cards) do
    cards
    |> Enum.map(&to_comparison/1)
    |> List.to_tuple()
  end
end
