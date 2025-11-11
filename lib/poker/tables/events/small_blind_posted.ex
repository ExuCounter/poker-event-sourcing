defmodule Poker.Tables.Events.SmallBlindPosted do
  @derive {Jason.Encoder, only: [:id, :table_id, :hand_id, :participant_id, :amount]}
  defstruct [:id, :table_id, :hand_id, :participant_id, :amount]
end
