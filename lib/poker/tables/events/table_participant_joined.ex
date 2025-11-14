defmodule Poker.Tables.Events.TableParticipantJoined do
  @derive {Jason.Encoder,
           only: [
             :id,
             :player_id,
             :table_id,
             :chips,
             :seat_number,
             :status,
             :bet_this_round,
             :is_sitting_out
           ]}
  defstruct [
    :id,
    :player_id,
    :table_id,
    :chips,
    :seat_number,
    :status,
    :bet_this_round,
    :is_sitting_out
  ]
end
