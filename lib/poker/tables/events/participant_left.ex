defmodule Poker.Tables.Events.ParticipantLeft do
  @derive {Jason.Encoder,
           only: [
             :table_id,
             :participant_id,
             :player_id,
             :chips
           ]}
  defstruct [
    :table_id,
    :participant_id,
    :player_id,
    :chips
  ]
end
