defmodule Poker.Tables.Aggregates.Table.Helpers do
  @moduledoc """
  Shared helper functions for table aggregate operations.
  """

  # Participant finders

  def find_participant_by_id(participants, participant_id) do
    Enum.find(participants, &(&1.id == participant_id))
  end

  def find_participant_index(participants, participant_id) do
    Enum.find_index(participants, &(&1.id == participant_id))
  end

  def find_participant_hand_by_position(participant_hands, position) do
    Enum.find(participant_hands, &(&1.position == position))
  end

  def find_participant_by_position(table, position) do
    hand = find_participant_hand_by_position(table.participant_hands, position)
    find_participant_by_id(table.participants, hand.participant_id)
  end

  def find_participant_index_by_position(table, position) do
    participant = find_participant_by_position(table, position)
    find_participant_index(table.participants, participant.id)
  end

  @doc """
  Checks if a participant is all-in (not busted and has no chips remaining).
  """
  def is_all_in?(participants, participant_id) do
    participant = find_participant_by_id(participants, participant_id)
    participant.status == :active and participant.chips == 0
  end

  def find_participant_to_act(%{round: %{type: :pre_flop, acted_participant_ids: []}} = table) do
    big_blind_index = find_participant_index_by_position(table, :big_blind)
    find_next_active_participant(table.participants, big_blind_index)
  end

  def find_participant_to_act(%{
        participants: participants,
        round: %{participant_to_act_id: participant_to_act_id}
      }) do
    find_participant_by_id(participants, participant_to_act_id)
  end

  def find_next_participant_to_act(table) do
    participant_to_act = find_participant_to_act(table)
    participant_index = find_participant_index(table.participants, participant_to_act.id)

    find_next_active_participant(table.participants, participant_index)
  end

  defp find_next_active_participant(participants, start_index) do
    total = length(participants)

    # Generate indices for one full cycle starting from next position
    indices = for offset <- 1..total, do: rem(start_index + offset, total)

    Enum.find_value(indices, fn index ->
      participant = Enum.at(participants, index)
      # Can act if not busted and has chips remaining
      if participant.status == :active and participant.chips > 0, do: participant
    end)
  end

  def find_dealer_button_participant(table) do
    if is_nil(table.dealer_button_id) do
      hd(table.participants)
    else
      dealer_index = find_participant_index(table.participants, table.dealer_button_id)
      next_dealer_index = next_participant_index(dealer_index, length(table.participants))

      Enum.at(table.participants, next_dealer_index)
    end
  end

  # Participant filters and updates

  def filter_active_participants(participants) do
    Enum.filter(participants, &(&1.status == :active))
  end

  def update_participant(table, participant_id, fun) when is_function(fun, 1) do
    updated_participants =
      Enum.map(table.participants, fn
        %{id: ^participant_id} = participant ->
          fun.(participant)

        participant ->
          participant
      end)

    %{table | participants: updated_participants}
  end

  def update_participant_hand(table, participant_id, fun) when is_function(fun, 1) do
    updated_participant_hands =
      Enum.map(table.participant_hands, fn
        %{participant_id: ^participant_id} = participant_hand ->
          fun.(participant_hand)

        participant_hand ->
          participant_hand
      end)

    %{table | participant_hands: updated_participant_hands}
  end

  # State checks

  def all_acted?(table) do
    acted_participant_ids = table.round.acted_participant_ids

    table.participants |> Enum.all?(fn participant -> participant.id in acted_participant_ids end)
  end

  def all_folded_except_one_participant?(table) do
    count_of_participant_hands = length(table.participant_hands)

    count_of_folded_participant_hands =
      table.participant_hands |> Enum.filter(fn hand -> hand.status in [:folded] end) |> length()

    count_of_participant_hands - 1 == count_of_folded_participant_hands
  end

  def runout?(table) do
    hands_in_play = Enum.reject(table.participant_hands, &(&1.status == :folded))

    hands_that_can_act =
      Enum.filter(hands_in_play, fn hand ->
        not is_all_in?(table.participants, hand.participant_id)
      end)

    length(hands_in_play) >= 2 and length(hands_that_can_act) <= 1
  end

  def heads_up?(table) do
    length(table.participant_hands) == 2
  end

  # Utility functions

  def next_participant_index(current_index, total_participants) do
    rem(current_index + 1, total_participants)
  end
end
