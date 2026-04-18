defmodule Poker.Tables.Aggregates.Table.Apply.Deck do
  @moduledoc """
  Applies deck-related events to aggregate state.

  Handles the following events:
  - `DeckGenerated` - Sets the initial shuffled deck
  - `DeckUpdated` - Updates remaining deck after cards are dealt
  - `DealerButtonMoved` - Updates dealer button position
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Events.{DeckGenerated, DeckUpdated, DealerButtonMoved}

  @doc "Sets the initial shuffled deck for the hand."
  def apply(%Table{} = table, %DeckGenerated{} = event) do
    %Table{table | remaining_deck: event.cards}
  end

  # Updates remaining deck after cards are dealt.
  def apply(%Table{} = table, %DeckUpdated{} = event) do
    %Table{table | remaining_deck: event.cards}
  end

  # Updates the dealer button position.
  def apply(%Table{} = table, %DealerButtonMoved{} = event) do
    %Table{table | dealer_button_id: event.participant_id}
  end
end
