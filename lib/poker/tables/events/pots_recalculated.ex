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
