defmodule Poker.Tables.Events.RoundStarted do
  @derive {Jason.Encoder,
           only: [
             :id,
             :hand_id,
             :table_id,
             :type,
             :community_cards
           ]}
  defstruct [
    :id,
    :hand_id,
    :table_id,
    :type,
    :community_cards
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.RoundStarted do
  def decode(%Poker.Tables.Events.RoundStarted{type: type} = event) do
    %Poker.Tables.Events.RoundStarted{event | type: type |> String.to_existing_atom()}
  end
end
