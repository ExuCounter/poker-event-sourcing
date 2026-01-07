defmodule Poker.Tables.Events.HandFinished do
  @derive {Jason.Encoder,
           only: [
             :table_id,
             :hand_id,
             :finish_reason
           ]}
  defstruct [
    :table_id,
    :hand_id,
    :finish_reason
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.HandFinished do
  def decode(%Poker.Tables.Events.HandFinished{} = event) do
    %Poker.Tables.Events.HandFinished{
      event
      | finish_reason: String.to_existing_atom(event.finish_reason)
    }
  end
end
