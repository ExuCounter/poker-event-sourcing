defmodule Poker.Tables.Events.ParticipantHandGiven do
  @derive {Jason.Encoder,
           only: [:id, :table_id, :participant_id, :table_hand_id, :hole_cards, :position, :status]}
  defstruct [:id, :table_id, :participant_id, :table_hand_id, :hole_cards, :position, :status]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.ParticipantHandGiven do
  def decode(%Poker.Tables.Events.ParticipantHandGiven{} = event) do
    %Poker.Tables.Events.ParticipantHandGiven{
      event
      | status: String.to_existing_atom(event.status)
    }
  end
end
