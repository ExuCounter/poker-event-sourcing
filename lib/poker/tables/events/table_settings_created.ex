defmodule Poker.Tables.Events.TableSettingsCreated do
  @derive {Jason.Encoder, only: [:id, :table_id, :small_blind, :big_blind, :starting_stack, :timeout_seconds]}
  use Poker, :schema

  embedded_schema do
    field :table_id, :binary_id
    field :small_blind, :integer
    field :big_blind, :integer
    field :starting_stack, :integer
    field :timeout_seconds, :integer
  end
end
