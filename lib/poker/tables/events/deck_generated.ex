defmodule Poker.Tables.Events.DeckGenerated do
  @derive {Jason.Encoder, only: [:hand_id, :table_id, :cards]}
  defstruct [:hand_id, :table_id, :cards]
end
