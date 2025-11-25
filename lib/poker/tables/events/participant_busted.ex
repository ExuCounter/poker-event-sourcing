defmodule Poker.Tables.Events.ParticipantBusted do
  @derive {Jason.Encoder,
           only: [
             :table_id,
             :hand_id,
             :participant_id
           ]}
  defstruct [
    :table_id,
    :hand_id,
    :participant_id
  ]
end
