defmodule Poker.Tables.Events.DeckGenerated do
  @derive {Jason.Encoder, only: [:hand_id, :table_id, :cards]}
  defstruct [:hand_id, :table_id, :cards]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.DeckGenerated do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.DeckGenerated{} = event) do
    %Poker.Tables.Events.DeckGenerated{
      event
      | cards: AtomDecoder.decode_cards(event.cards)
    }
  end
end
