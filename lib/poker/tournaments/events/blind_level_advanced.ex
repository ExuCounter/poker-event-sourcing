defmodule Poker.Tournaments.Events.BlindLevelAdvanced do
  @derive {Jason.Encoder,
           only: [
             :tournament_id,
             :level,
             :small_blind,
             :big_blind,
             :duration_seconds
           ]}
  defstruct [
    :tournament_id,
    :level,
    :small_blind,
    :big_blind,
    :duration_seconds
  ]
end
