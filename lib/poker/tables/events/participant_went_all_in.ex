defmodule Poker.Tables.Events.ParticipantWentAllIn do
  @derive {Jason.Encoder,
           only: [
             :participant_id,
             :hand_id,
             :table_id,
             :status,
             :amount,
             :round
           ]}
  defstruct [
    :participant_id,
    :hand_id,
    :table_id,
    :status,
    :amount,
    :round
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.ParticipantWentAllIn do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.ParticipantWentAllIn{} = event) do
    %Poker.Tables.Events.ParticipantWentAllIn{
      event
      | status: AtomDecoder.decode(:participant_status, event.status),
        round: AtomDecoder.decode(:round_type, event.round)
    }
  end
end
