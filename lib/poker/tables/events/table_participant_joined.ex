defmodule Poker.Tables.Events.ParticipantJoined do
  @derive {Jason.Encoder,
           only: [
             :id,
             :player_id,
             :table_id,
             :chips,
             :initial_chips,
             :status,
             :is_sitting_out
           ]}
  defstruct [
    :id,
    :player_id,
    :table_id,
    :chips,
    :initial_chips,
    :status,
    :is_sitting_out
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.ParticipantJoined do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.ParticipantJoined{status: status} = event) do
    %Poker.Tables.Events.ParticipantJoined{
      event
      | status: AtomDecoder.decode(:participant_status, status)
    }
  end
end
