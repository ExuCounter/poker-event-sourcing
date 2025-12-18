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
