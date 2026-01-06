defmodule Poker.Tables.Events.ParticipantShowdownCardsRevealed do
  @derive {Jason.Encoder,
           only: [
             :table_id,
             :hand_id,
             :participant_id,
             :hole_cards
           ]}
  defstruct [
    :table_id,
    :hand_id,
    :participant_id,
    :hole_cards
  ]
end
