defmodule Poker.Tables.Events.ParticipantBoughtIn do
  @derive {Jason.Encoder,
           only: [
             :participant_id,
             :player_id,
             :table_id,
             :amount
           ]}
  defstruct [
    :participant_id,
    :player_id,
    :table_id,
    :amount
  ]
end
