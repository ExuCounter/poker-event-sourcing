defmodule Poker.Tables.Events.ParticipantShowdownCardsRevealed do
  @derive {Jason.Encoder,
           only: [
             :table_id,
             :hand_id,
             :participant_id,
             :hole_cards
           ]}
  defstruct [
    :table_id,
    :hand_id,
    :participant_id,
    :hole_cards
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.ParticipantShowdownCardsRevealed do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.ParticipantShowdownCardsRevealed{} = event) do
    %Poker.Tables.Events.ParticipantShowdownCardsRevealed{
      event
      | hole_cards: AtomDecoder.decode_cards(event.hole_cards)
    }
  end
end
