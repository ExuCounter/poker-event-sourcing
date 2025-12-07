defmodule Poker.Tables.Aggregates.Table.Apply.Deck do
  @moduledoc """
  Handles deck event application.
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Events.{DeckGenerated, DeckUpdated, DealerButtonMoved}

  def apply(%Table{} = table, %DeckGenerated{} = event) do
    %Table{table | remaining_deck: event.cards}
  end

  def apply(%Table{} = table, %DeckUpdated{} = event) do
    %Table{table | remaining_deck: event.cards}
  end

  def apply(%Table{} = table, %DealerButtonMoved{} = event) do
    %Table{table | dealer_button_id: event.participant_id}
  end
end
