defmodule Poker.Tables.Aggregates.Table.Position do
  @moduledoc """
  Handles position calculation for poker table participants.
  Positions include: dealer, small_blind, big_blind, utg, hijack, cutoff.
  """

  @doc """
  Calculates the poker position for a participant based on dealer button and player count.
  """
  def calculate_position(table, participant) do
    total_players = length(table.participants)
    dealer_index = Enum.find_index(table.participants, &(&1.id == table.dealer_button_id))
    participant_index = Enum.find_index(table.participants, &(&1.id == participant.id))

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

  defp find_participant_by_id(table, participant_id) do
    Enum.find(table.participants, &(&1.id == participant_id))
  end
end
