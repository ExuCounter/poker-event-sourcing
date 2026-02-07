defmodule Poker.Tables.Events.ParticipantToActSelected do
  @derive {Jason.Encoder,
           only: [:table_id, :round_id, :participant_id, :timeout_seconds, :started_at]}
  defstruct [:table_id, :round_id, :participant_id, :timeout_seconds, :started_at]
end
