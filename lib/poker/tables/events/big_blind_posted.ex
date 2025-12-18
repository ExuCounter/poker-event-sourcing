defmodule Poker.Tables.Events.BigBlindPosted do
  @derive {Jason.Encoder,
           only: [:id, :table_id, :hand_id, :participant_id, :amount, :participant_hand_id]}
  defstruct [:id, :table_id, :hand_id, :participant_id, :amount, :participant_hand_id]
end
