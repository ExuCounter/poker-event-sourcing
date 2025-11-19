defmodule Poker.Services.Deck do
  @behaviour Poker.Services.Deck.Behaviour

  @impl true
  def generate_deck() do
    config(:dispatcher).generate_deck()
  end

  @impl true
  def shuffle_deck(deck) do
    config(:dispatcher).shuffle_deck(deck)
  end

  @impl true
  def pick_cards(deck, count) do
    config(:dispatcher).pick_cards(deck, count)
  end

  def config(key) do
    Keyword.fetch!(Application.fetch_env!(:poker, __MODULE__), key)
  end
end
