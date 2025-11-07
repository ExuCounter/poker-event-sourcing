defmodule Poker.Tables.Events.TableSettingsCreated do
  @derive {Jason.Encoder, only: [:id, :table_id, :small_blind, :big_blind, :starting_stack, :timeout_seconds]}
  defstruct [:id, :table_id, :small_blind, :big_blind, :starting_stack, :timeout_seconds]
end
