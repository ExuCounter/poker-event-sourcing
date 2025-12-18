defmodule Poker.Tables.Events.ParticipantRaised do
  @derive {Jason.Encoder,
           only: [
             :id,
             :participant_id,
             :table_hand_id,
             :table_id,
             :status,
             :amount,
             :round
           ]}
  defstruct [
    :id,
    :participant_id,
    :table_hand_id,
    :table_id,
    :status,
    :amount,
    :round
  ]
end
