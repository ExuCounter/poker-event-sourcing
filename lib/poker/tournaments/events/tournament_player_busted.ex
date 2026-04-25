defmodule Poker.Tournaments.Events.TournamentPlayerBusted do
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
