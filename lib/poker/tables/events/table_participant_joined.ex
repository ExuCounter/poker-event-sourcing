defmodule Poker.Tables.Events.TableParticipantJoined do
  @derive {Jason.Encoder, only: [:id, :player_id, :table_id, :chips, :seat_number, :status]}
  defstruct [:id, :player_id, :table_id, :chips, :seat_number, :status]
end
