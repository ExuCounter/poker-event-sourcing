defmodule Poker.DeckFixtures do
  import Mox

  @dealing_order %{
    dealer: 0,
    small_blind: 1,
    big_blind: 2,
    utg: 3,
    hijack: 4,
    cutoff: 5
  }

  @doc """
  Arranges the deck so specific positions receive specific hole cards.

  Stubs `generate_deck` to return the arranged deck and `shuffle_deck` as no-op.
  `pick_cards` stays default (`Enum.split`), so cards are dealt off the top in order.

  ## Example

      arrange_deck(%{
        dealer: [%{rank: :A, suit: :spades}, %{rank: :K, suit: :spades}],
        big_blind: [%{rank: 7, suit: :hearts}, %{rank: 7, suit: :clubs}],
        community: [
          %{rank: :Q, suit: :spades}, %{rank: :J, suit: :spades}, %{rank: :T, suit: :spades},
          %{rank: 7, suit: :diamonds}, %{rank: 2, suit: :diamonds}
        ]
      })
  """
  def arrange_deck(hands) do
    community = Map.get(hands, :community, [])

    hole_cards =
      hands
      |> Map.drop([:community])
      |> Enum.sort_by(fn {position, _cards} -> Map.fetch!(@dealing_order, position) end)
      |> Enum.flat_map(fn {_position, cards} -> cards end)

    filler = Poker.Services.DeckStub.generate_deck()
    deck = hole_cards ++ community ++ filler

    arranged = deck

    stub(Poker.Services.DeckMock, :generate_deck, fn -> arranged end)
    stub(Poker.Services.DeckMock, :shuffle_deck, fn deck -> deck end)
    stub(Poker.Services.DeckMock, :pick_cards, &Poker.Services.DeckStub.pick_cards/2)

    :ok
  end
end
