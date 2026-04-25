defmodule Poker.Tournaments.BlindStructure do
  @moduledoc """
  Defines blind level progressions and durations per tournament speed.
  """

  @levels [
    %{level: 1, small_blind: 10, big_blind: 20},
    %{level: 2, small_blind: 15, big_blind: 30},
    %{level: 3, small_blind: 20, big_blind: 40},
    %{level: 4, small_blind: 30, big_blind: 60},
    %{level: 5, small_blind: 50, big_blind: 100},
    %{level: 6, small_blind: 75, big_blind: 150},
    %{level: 7, small_blind: 100, big_blind: 200},
    %{level: 8, small_blind: 150, big_blind: 300},
    %{level: 9, small_blind: 200, big_blind: 400},
    %{level: 10, small_blind: 300, big_blind: 600}
  ]

  @durations %{
    regular: 600,
    turbo: 300,
    hyper_turbo: 180
  }

  @starting_stacks %{
    regular: 1500,
    turbo: 1500,
    hyper_turbo: 500
  }

  def levels, do: @levels

  def duration_seconds(speed), do: Map.fetch!(@durations, speed)

  def starting_stack(speed), do: Map.fetch!(@starting_stacks, speed)

  def levels_for(speed) do
    duration = duration_seconds(speed)

    Enum.map(@levels, fn level ->
      Map.put(level, :duration_seconds, duration)
    end)
  end

  def get_level(level_number) do
    Enum.find(@levels, fn l -> l.level == level_number end)
  end

  def max_level, do: length(@levels)

  def max_players(:two_max), do: 2
  def max_players(:three_max), do: 3
  def max_players(:four_max), do: 4
  def max_players(:six_max), do: 6

  @payout_structures %{
    2 => [{1, 100}],
    3 => [{1, 65}, {2, 35}],
    4 => [{1, 65}, {2, 35}],
    5 => [{1, 70}, {2, 30}],
    6 => [{1, 70}, {2, 30}]
  }

  def payout_structure(total_players) do
    Map.fetch!(@payout_structures, total_players)
  end

  def calculate_payouts(total_players, buy_in) do
    prize_pool = total_players * buy_in
    structure = payout_structure(total_players)

    payouts =
      Enum.map(structure, fn {position, pct} ->
        %{position: position, payout_amount: div(prize_pool * pct, 100)}
      end)

    # Award remainder to 1st place
    total_paid = Enum.sum(Enum.map(payouts, & &1.payout_amount))
    remainder = prize_pool - total_paid

    if remainder > 0 do
      Enum.map(payouts, fn
        %{position: 1} = p -> %{p | payout_amount: p.payout_amount + remainder}
        p -> p
      end)
    else
      payouts
    end
  end
end
