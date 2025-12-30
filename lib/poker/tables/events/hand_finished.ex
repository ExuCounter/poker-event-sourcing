defmodule Poker.Tables.Events.HandFinished do
  @derive {Jason.Encoder,
           only: [
             :table_id,
             :hand_id,
             :finish_reason,
             :payouts
           ]}
  defstruct [
    :table_id,
    :hand_id,
    :finish_reason,
    :payouts
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.HandFinished do
  def decode(%Poker.Tables.Events.HandFinished{payouts: payouts} = event) do
    payouts =
      Enum.map(payouts, fn payout ->
        hand_rank =
          case payout.hand_rank do
            nil ->
              nil

            hand_rank ->
              hand_rank
              |> Poker.HandRank.decode()
              |> Poker.HandRank.to_map()
          end

        %{payout | hand_rank: hand_rank}
      end)

    %Poker.Tables.Events.HandFinished{
      event
      | payouts: payouts,
        finish_reason: String.to_existing_atom(event.finish_reason)
    }
  end
end
