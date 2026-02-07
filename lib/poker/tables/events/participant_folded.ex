defmodule Poker.Tables.Events.ParticipantFolded do
  @derive {Jason.Encoder,
           only: [
             :id,
             :participant_id,
             :table_hand_id,
             :table_id,
             :status,
             :round,
             :folded_at
           ]}
  defstruct [
    :id,
    :participant_id,
    :table_hand_id,
    :table_id,
    :status,
    :round,
    :folded_at
  ]
end
