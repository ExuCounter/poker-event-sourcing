defmodule Poker.Tables.Events.ParticipantHandGiven do
  @derive {Jason.Encoder,
           only: [
             :id,
             :table_id,
             :participant_id,
             :table_hand_id,
             :hole_cards,
             :position,
             :status,
             :bet_this_round,
             :total_bet_this_hand
           ]}
  defstruct [
    :id,
    :table_id,
    :participant_id,
    :table_hand_id,
    :hole_cards,
    :position,
    :status,
    :bet_this_round,
    :total_bet_this_hand
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.ParticipantHandGiven do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.ParticipantHandGiven{} = event) do
    %Poker.Tables.Events.ParticipantHandGiven{
      event
      | status: AtomDecoder.decode(:participant_status, event.status),
        position: AtomDecoder.decode(:participant_position, event.position)
    }
  end
end
