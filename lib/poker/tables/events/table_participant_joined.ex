defmodule Poker.Tables.Events.TableParticipantJoined do
  @derive {Jason.Encoder,
           only: [
             :id,
             :player_id,
             :table_id,
             :chips,
             :initial_chips,
             :seat_number,
             :status,
             :bet_this_round,
             :total_bet_this_hand,
             :is_sitting_out
           ]}
  defstruct [
    :id,
    :player_id,
    :table_id,
    :chips,
    :initial_chips,
    :seat_number,
    :status,
    :bet_this_round,
    :is_sitting_out,
    :total_bet_this_hand
  ]
end
