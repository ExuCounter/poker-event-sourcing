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
  defp decode_status("playing"), do: :playing
  defp decode_status("folded"), do: :folded
  defp decode_status("all_in"), do: :all_in

  def decode(%Poker.Tables.Events.ParticipantHandGiven{} = event) do
    %Poker.Tables.Events.ParticipantHandGiven{
      event
      | status: decode_status(event.status),
        position: String.to_existing_atom(event.position)
    }
  end
end
