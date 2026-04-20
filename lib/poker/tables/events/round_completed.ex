defmodule Poker.Tables.Events.RoundCompleted do
  @derive {Jason.Encoder,
           only: [
             :id,
             :hand_id,
             :table_id,
             :type,
             :reason
           ]}
  defstruct [
    :id,
    :hand_id,
    :table_id,
    :type,
    :reason
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.RoundCompleted do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.RoundCompleted{} = event) do
    %Poker.Tables.Events.RoundCompleted{
      event
      | type: AtomDecoder.decode(:round_type, event.type),
        reason: AtomDecoder.decode(:round_reason, event.reason)
    }
  end
end
