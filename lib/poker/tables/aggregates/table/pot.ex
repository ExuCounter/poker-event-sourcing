defmodule Poker.Tables.Aggregates.Table.Pot do
  @moduledoc """
  Handles pot calculation logic for poker tables.
  Manages main pots and side pots based on participant betting.
  """

  @doc """
  Recalculates all pots based on current participant bets.
  Returns a list of pots with main and side pots properly structured.
  """
  def recalculate_pots(table) do
    unique_bet_amounts =
      table.participants
      |> Enum.map(& &1.total_bet_this_hand)
      |> Enum.filter(&(&1 > 0))
      |> Enum.uniq()
      |> Enum.sort()

    unique_bet_amounts
    |> Enum.reduce([], fn bet_amount, pots ->
      contributing_participants =
        table.participants
        |> Enum.filter(&(&1.total_bet_this_hand >= bet_amount))
        |> filter_active_participants()

      previous_bet_amount =
        if pots == [] do
          0
        else
          pots |> List.last() |> Map.get(:bet_amount)
        end

      bet_amount = bet_amount - previous_bet_amount
      pot_amount = bet_amount * length(contributing_participants)

      pots ++
        [
          %{
            bet_amount: bet_amount,
            amount: pot_amount,
            contributing_participant_ids: Enum.map(contributing_participants, & &1.id)
          }
        ]
    end)
    |> Enum.with_index()
    |> Enum.map(fn {pot, index} ->
      type = if index == 0, do: :main, else: :side
      Map.put(pot, :type, type)
    end)
  end

  defp filter_active_participants(participants) do
    Enum.filter(participants, &(&1.status == :active))
  end
end
