defmodule Poker.Tables.Events.HandStarted do
  @derive {Jason.Encoder,
           only: [
             :id,
             :table_id,
             :dealer_button_id,
             :community_cards
           ]}
  defstruct [
    :id,
    :table_id,
    :dealer_button_id,
    :community_cards
  ]
end
