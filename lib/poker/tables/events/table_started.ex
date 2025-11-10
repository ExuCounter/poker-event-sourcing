defmodule Poker.Tables.Events.TableStarted do
  @derive {Jason.Encoder, only: [:id, :status, :dealer_button_id]}
  defstruct [:id, :status, :dealer_button_id]
end
