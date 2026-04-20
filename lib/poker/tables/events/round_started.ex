defmodule Poker.Tables.Events.RoundStarted do
  @derive {Jason.Encoder,
           only: [
             :id,
             :hand_id,
             :table_id,
             :type,
             :community_cards
           ]}
  defstruct [
    :id,
    :hand_id,
    :table_id,
    :type,
    :community_cards
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.RoundStarted do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.RoundStarted{type: type} = event) do
    %Poker.Tables.Events.RoundStarted{
      event
      | type: AtomDecoder.decode(:round_type, type),
        community_cards: AtomDecoder.decode_cards(event.community_cards)
    }
  end
end
