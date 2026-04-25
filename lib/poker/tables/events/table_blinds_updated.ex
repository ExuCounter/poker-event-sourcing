defmodule Poker.Tables.Events.TableBlindsUpdated do
  @derive {Jason.Encoder, only: [:table_id, :small_blind, :big_blind]}
  defstruct [:table_id, :small_blind, :big_blind]
end
