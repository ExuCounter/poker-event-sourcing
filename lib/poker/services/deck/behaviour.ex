defmodule Poker.Services.Deck.Behaviour do
  @callback generate_deck() :: [atom()]
  @callback shuffle_deck(list()) :: list()
  @callback pick_card(list()) :: {:ok, atom(), list()} | {:error, atom()}
  @callback pick_cards(list(), integer()) :: {:ok, list(), list()} | {:error, atom()}
end
