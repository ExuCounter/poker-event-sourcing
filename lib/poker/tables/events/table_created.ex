defmodule Poker.Tables.Events.TableCreated do
  @derive {Jason.Encoder, only: [:id, :creator_id, :status, :settings]}
  defstruct [:id, :creator_id, :status, :settings]
end
