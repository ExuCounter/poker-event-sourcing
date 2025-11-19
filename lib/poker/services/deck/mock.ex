defmodule Poker.Services.Deck.Mock do
  @behaviour Poker.Services.Deck.Behaviour

  @impl true
  def generate_deck do
    ranks = [2, 3, 4, 5, 6, 7, 8, 9, :T, :J, :Q, :K, :A]
    suits = [:hearts, :diamonds, :clubs, :spades]

    deck =
      for rank <- ranks, suit <- suits do
        %{rank: rank, suit: suit}
      end
  end

  @impl true
  def shuffle_deck(deck) do
    Enum.shuffle(deck)
  end

  @impl true
  def pick_cards(deck, count) do
    Enum.split(deck, count)
  end
end
