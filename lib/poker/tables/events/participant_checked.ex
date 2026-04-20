defmodule Poker.Tables.Events.ParticipantChecked do
  @derive {Jason.Encoder,
           only: [
             :participant_id,
             :hand_id,
             :table_id,
             :status,
             :round
           ]}
  defstruct [
    :participant_id,
    :hand_id,
    :table_id,
    :status,
    :round
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.ParticipantChecked do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.ParticipantChecked{} = event) do
    %Poker.Tables.Events.ParticipantChecked{
      event
      | status: AtomDecoder.decode(:participant_status, event.status),
        round: AtomDecoder.decode(:round_type, event.round)
    }
  end
end
