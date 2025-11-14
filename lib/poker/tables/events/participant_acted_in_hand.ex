defmodule Poker.Tables.Events.ParticipantActedInHand do
  @derive {Jason.Encoder,
           only: [
             :id,
             :participant_id,
             :table_hand_id,
             :action,
             :amount,
             :round,
             :next_participant_to_act_id
           ]}
  defstruct [
    :id,
    :participant_id,
    :table_hand_id,
    :action,
    :amount,
    :round,
    :next_participant_to_act_id
  ]
end
