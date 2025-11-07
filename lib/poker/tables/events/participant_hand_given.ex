defmodule Poker.Tables.Events.ParticipantHandGiven do
  @derive {Jason.Encoder, only: [:id, :table_id, :participant_id, :table_hand_id, :hole_cards]}
  defstruct [:id, :table_id, :participant_id, :table_hand_id, :hole_cards]
end
