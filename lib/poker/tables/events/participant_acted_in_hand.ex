defmodule Poker.Tables.Events.ParticipantActedInHand do
  @derive {Jason.Encoder,
           only: [:id, :participant_id, :table_hand_id, :action, :amount, :round]}
  defstruct [:id, :participant_id, :table_hand_id, :action, :amount, :round]
end
