defmodule Poker.Tables.Events.PotsRecalculated do
  @derive {Jason.Encoder,
           only: [
             :id,
             :table_id,
             :hand_id,
             :pots
           ]}
  defstruct [
    :id,
    :table_id,
    :hand_id,
    :pots
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.PotsRecalculated do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.PotsRecalculated{} = event) do
    %Poker.Tables.Events.PotsRecalculated{
      event
      | pots: AtomDecoder.decode_pots(event.pots)
    }
  end
end
