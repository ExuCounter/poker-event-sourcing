defmodule Poker.Tables.Events.ParticipantBuyInApplied do
  @derive {Jason.Encoder,
           only: [
             :participant_id,
             :table_id,
             :amount
           ]}
  defstruct [
    :participant_id,
    :table_id,
    :amount
  ]
end
