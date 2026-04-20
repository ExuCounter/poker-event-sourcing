defmodule Poker.Tables.Events.ParticipantToActSelected do
  @derive {Jason.Encoder,
           only: [:table_id, :round_id, :participant_id, :timeout_seconds, :started_at]}
  defstruct [:table_id, :round_id, :participant_id, :timeout_seconds, :started_at]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.ParticipantToActSelected do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.ParticipantToActSelected{} = event) do
    %Poker.Tables.Events.ParticipantToActSelected{
      event
      | started_at: AtomDecoder.decode_datetime(event.started_at)
    }
  end
end
