defmodule Poker.Tables.Events.TableStarted do
  @derive {Jason.Encoder, only: [:id, :status]}
  defstruct [:id, :status]
end
