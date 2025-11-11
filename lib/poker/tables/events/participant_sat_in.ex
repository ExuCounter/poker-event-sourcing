defmodule Poker.Tables.Events.ParticipantSatIn do
  @derive {Jason.Encoder, only: [:participant_id, :table_id]}
  defstruct [:participant_id, :table_id]
end
