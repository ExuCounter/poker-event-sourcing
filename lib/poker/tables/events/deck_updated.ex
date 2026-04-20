defmodule Poker.Tables.Events.DeckUpdated do
  @derive {Jason.Encoder, only: [:hand_id, :table_id, :cards]}
  defstruct [:hand_id, :table_id, :cards]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.DeckUpdated do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.DeckUpdated{} = event) do
    %Poker.Tables.Events.DeckUpdated{
      event
      | cards: AtomDecoder.decode_cards(event.cards)
    }
  end
end
