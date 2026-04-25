defmodule Poker.Tournaments.Events.PlayerRegistered do
  @derive {Jason.Encoder,
           only: [
             :tournament_id,
             :player_id
           ]}
  defstruct [
    :tournament_id,
    :player_id
  ]
end
