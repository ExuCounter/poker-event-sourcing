defmodule Poker.Tournaments.Events.TournamentStarted do
  @derive {Jason.Encoder, only: [:tournament_id]}
  defstruct [:tournament_id]
end
