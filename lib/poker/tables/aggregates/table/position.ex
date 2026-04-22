defmodule Poker.Tables.Aggregates.Table.Position do
  @moduledoc """
  Handles position calculation for poker table participants.
  Positions include: dealer, small_blind, big_blind, utg, hijack, cutoff.
  """

  @doc """
  Calculates the poker position for a participant based on dealer button and player count.

  For cash games, pass only playing participants (not sitting out).
  For tournaments, pass all participants.
  """
  def calculate_position(table, participant, playing_participants) do
    total_players = length(playing_participants)
    dealer_index = Enum.find_index(playing_participants, &(&1.id == table.dealer_button_id))

    # If dealer is not in playing_participants (sitting out in cash game), find next dealer
    dealer_index =
      if is_nil(dealer_index) do
        find_effective_dealer_index(table, playing_participants)
      else
        dealer_index
      end

    participant_index = Enum.find_index(playing_participants, &(&1.id == participant.id))

    # Find relative position from dealer (0 = dealer, 1 = next, etc.)
    relative_position =
      calculate_relative_position(
        dealer_index,
        participant_index,
        total_players
      )

    case total_players do
      2 -> calculate_heads_up_position(relative_position)
      3 -> calculate_three_handed_position(relative_position)
      4 -> calculate_four_handed_position(relative_position)
      5 -> calculate_five_handed_position(relative_position)
      6 -> calculate_six_handed_position(relative_position)
    end
  end

  defp calculate_relative_position(dealer_index, participant_index, total_participants) do
    rem(participant_index - dealer_index + total_participants, total_participants)
  end

  defp find_effective_dealer_index(table, playing_participants) do
    dealer_index = Enum.find_index(table.participants, &(&1.id == table.dealer_button_id))
    total_participants = length(table.participants)
    playing_participant_ids = MapSet.new(playing_participants, & &1.id)

    effective_dealer_id =
      Enum.find_value(0..(total_participants - 1), fn offset ->
        participant = Enum.at(table.participants, rem(dealer_index + offset, total_participants))
        if MapSet.member?(playing_participant_ids, participant.id), do: participant.id
      end)

    Enum.find_index(playing_participants, &(&1.id == effective_dealer_id))
  end

  # Heads up (2 players): Dealer is also SB, other is BB
  defp calculate_heads_up_position(0), do: :dealer
  defp calculate_heads_up_position(1), do: :big_blind

  # 3-handed: Dealer, SB, BB
  defp calculate_three_handed_position(0), do: :dealer
  defp calculate_three_handed_position(1), do: :small_blind
  defp calculate_three_handed_position(2), do: :big_blind

  # 4-handed: Dealer, SB, BB, CO
  defp calculate_four_handed_position(0), do: :dealer
  defp calculate_four_handed_position(1), do: :small_blind
  defp calculate_four_handed_position(2), do: :big_blind
  defp calculate_four_handed_position(3), do: :cutoff

  # 5-handed: Dealer, SB, BB, UTG, CO
  defp calculate_five_handed_position(0), do: :dealer
  defp calculate_five_handed_position(1), do: :small_blind
  defp calculate_five_handed_position(2), do: :big_blind
  defp calculate_five_handed_position(3), do: :utg
  defp calculate_five_handed_position(4), do: :cutoff

  # 6-handed: Dealer, SB, BB, UTG, HJ, CO
  defp calculate_six_handed_position(0), do: :dealer
  defp calculate_six_handed_position(1), do: :small_blind
  defp calculate_six_handed_position(2), do: :big_blind
  defp calculate_six_handed_position(3), do: :utg
  defp calculate_six_handed_position(4), do: :hijack
  defp calculate_six_handed_position(5), do: :cutoff
end
