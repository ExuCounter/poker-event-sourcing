defmodule Poker.Tables.Events.TableResumed do
  @derive {Jason.Encoder, only: [:table_id]}
  defstruct [:table_id]
end
