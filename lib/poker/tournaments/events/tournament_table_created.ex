defmodule Poker.Tournaments.Events.TournamentTableCreated do
  @derive {Jason.Encoder,
           only: [
             :tournament_id,
             :table_id
           ]}
  defstruct [
    :tournament_id,
    :table_id
  ]
end
