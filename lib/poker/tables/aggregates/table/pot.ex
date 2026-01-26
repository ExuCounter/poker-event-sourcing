defmodule Poker.Tables.Aggregates.Table.Pot do
  @moduledoc """
  Handles pot calculation logic for poker tables.
  Manages main pots and side pots based on participant betting.
  """

  @doc """
  Recalculates all pots based on current participant bets.
  Returns a list of pots with main and side pots properly structured.
  """
  def recalculate_pots(participant_hands) do
    unique_bet_amounts =
      participant_hands
      |> Enum.map(& &1.total_bet_this_hand)
      |> Enum.filter(&(&1 > 0))
      |> Enum.uniq()
      |> Enum.sort()

    unique_bet_amounts
    |> Enum.reduce([], fn bet_amount, pots ->
      contributing_participant_hands =
        participant_hands
        |> Enum.filter(&(&1.total_bet_this_hand >= bet_amount))

      previous_bet_amount = Enum.sum_by(pots, & &1.bet_amount)

      bet_amount = bet_amount - previous_bet_amount
      pot_amount = bet_amount * length(contributing_participant_hands)

      pots ++
        [
          %{
            id: UUIDv7.generate(),
            bet_amount: bet_amount,
            amount: pot_amount,
            contributing_participant_ids:
              contributing_participant_hands
              |> filter_active_participant_hands()
              |> Enum.map(& &1.participant_id)
          }
        ]
    end)
    |> Enum.with_index()
    |> Enum.map(fn {pot, index} ->
      type = if index == 0, do: :main, else: :side
      Map.put(pot, :type, type)
    end)
  end

  defp filter_active_participant_hands(participant_hands) do
    Enum.filter(participant_hands, &(&1.status == :playing))
  end
end
