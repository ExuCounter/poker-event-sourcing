defmodule Poker.Tables.Events.PayoutDistributed do
  @derive {Jason.Encoder,
           only: [
             :table_id,
             :hand_id,
             :pot_id,
             :participant_id,
             :amount,
             :pot_type,
             :hand_rank
           ]}
  defstruct [
    :table_id,
    :hand_id,
    :pot_id,
    :participant_id,
    :amount,
    :pot_type,
    :hand_rank
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.PayoutDistributed do
  def decode(%Poker.Tables.Events.PayoutDistributed{} = event) do
    hand_rank =
      case event.hand_rank do
        nil ->
          nil

        rank_string ->
          rank_string
          |> Poker.HandRank.decode()
          |> Poker.HandRank.to_map()
      end

    %Poker.Tables.Events.PayoutDistributed{
      event
      | pot_type: String.to_existing_atom(event.pot_type),
        hand_rank: hand_rank
    }
  end
end
