defmodule Poker.Tables.Events.TableStarted do
  @derive {Jason.Encoder, only: [:id, :status, :dealer_button_id, :hand_id]}
  defstruct [:id, :status, :dealer_button_id, :hand_id]
end
