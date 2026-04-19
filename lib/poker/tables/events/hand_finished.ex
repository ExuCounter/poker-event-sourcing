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
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.HandFinished{finish_reason: finish_reason} = event) do
    %Poker.Tables.Events.HandFinished{
      event
      | finish_reason: AtomDecoder.decode(:hand_finish_reason, finish_reason)
    }
  end
end
