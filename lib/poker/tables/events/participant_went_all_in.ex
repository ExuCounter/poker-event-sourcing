defmodule Poker.Tables.Events.ParticipantWentAllIn do
  @derive {Jason.Encoder,
           only: [
             :participant_id,
             :hand_id,
             :table_id,
             :status,
             :amount,
             :round
           ]}
  defstruct [
    :participant_id,
    :hand_id,
    :table_id,
    :status,
    :amount,
    :round
  ]
end
