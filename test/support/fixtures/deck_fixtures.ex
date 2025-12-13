defmodule Poker.DeckFixtures do
  import Mox

  def setup_winning_hand(ctx) do
    # Player 1 gets winner
    expect(Poker.Services.DeckMock, :pick_cards, fn _deck, 2 ->
      {[%{rank: :A, suit: :spades}, %{rank: :K, suit: :spades}], []}
    end)

    # Other players get unique losing hands
    losing_hands = [
      {[%{rank: 2, suit: :hearts}, %{rank: 7, suit: :clubs}], []},
      {[%{rank: 3, suit: :hearts}, %{rank: 8, suit: :clubs}], []},
      {[%{rank: 4, suit: :hearts}, %{rank: 9, suit: :clubs}], []},
      {[%{rank: 5, suit: :hearts}, %{rank: :T, suit: :clubs}], []},
      {[%{rank: 6, suit: :hearts}, %{rank: :J, suit: :clubs}], []}
    ]

    losing_hands
    |> Enum.take(length(ctx.table.participants) - 1)
    |> Enum.each(fn hand ->
      expect(Poker.Services.DeckMock, :pick_cards, fn _deck, 2 -> hand end)
    end)

    # # Community
    expect(Poker.Services.DeckMock, :pick_cards, fn _deck, 3 ->
      {[%{rank: :Q, suit: :spades}, %{rank: :J, suit: :spades}, %{rank: :T, suit: :spades}], []}
    end)

    expect(Poker.Services.DeckMock, :pick_cards, fn _deck, 1 ->
      {[%{rank: 2, suit: :diamonds}], []}
    end)

    expect(Poker.Services.DeckMock, :pick_cards, fn _deck, 1 ->
      {[%{rank: 3, suit: :diamonds}], []}
    end)

    ctx
  end
end
