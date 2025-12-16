defmodule Poker.Tables.Events.ParticipantToActSelected do
  @derive {Jason.Encoder, only: [:table_id, :round_id, :participant_id]}
  defstruct [:table_id, :round_id, :participant_id]
end
