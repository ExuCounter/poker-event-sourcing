defmodule Poker.Tables.Events.PayoutDistributed do
  defstruct [:table_id, :hand_id, :pot_id, :participant_id, :amount, :pot_type, :hand_rank]
end

defimpl Jason.Encoder, for: Poker.Tables.Events.PayoutDistributed do
  def encode(event, opts) do
    event
    |> Map.from_struct()
    |> Map.update(:hand_rank, nil, &encode_hand_rank/1)
    |> Jason.Encode.map(opts)
  end

  defp encode_hand_rank(nil), do: nil
  defp encode_hand_rank(tuple) when is_tuple(tuple), do: Poker.HandRank.encode(tuple)
  defp encode_hand_rank(list) when is_list(list), do: list
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.PayoutDistributed do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.PayoutDistributed{} = event) do
    %{event |
      pot_type: AtomDecoder.decode(:pot_type, event.pot_type),
      hand_rank: AtomDecoder.decode(:hand_rank, event.hand_rank)
    }
  end
end
