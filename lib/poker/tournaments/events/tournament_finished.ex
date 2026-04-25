defmodule Poker.Tournaments.Events.TournamentFinished do
  @derive {Jason.Encoder,
           only: [
             :tournament_id,
             :prize_pool,
             :payouts
           ]}
  defstruct [
    :tournament_id,
    :prize_pool,
    :payouts
  ]
end
