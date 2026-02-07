defmodule Poker.Tables.Events.ParticipantTimedOut do
  @derive {Jason.Encoder,
           only: [
             :id,
             :table_id,
             :participant_id,
             :round_id
           ]}

  defstruct [
    :id,
    :table_id,
    :participant_id,
    :round_id
  ]
end
