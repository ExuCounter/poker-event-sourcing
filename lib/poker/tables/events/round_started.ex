defmodule Poker.Tables.Events.RoundStarted do
  @derive {Jason.Encoder,
           only: [
             :id,
             :hand_id,
             :type,
             :last_bet_amount,
             :community_cards
           ]}
  defstruct [
    :id,
    :hand_id,
    :type,
    :last_bet_amount,
    :community_cards
  ]
end
