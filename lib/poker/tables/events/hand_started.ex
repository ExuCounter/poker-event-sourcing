defmodule Poker.Tables.Events.HandStarted do
  @derive {Jason.Encoder, only: [:id, :table_id]}
  defstruct [:id, :table_id]
end
