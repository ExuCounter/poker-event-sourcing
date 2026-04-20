defmodule Poker.Tables.Aggregates.Table.Helpers do
  @moduledoc """
  Shared helper functions for table aggregate operations.

  This module provides utilities for:

  ## Participant Lookups
  - Finding participants by ID, index, or position
  - Finding the next participant to act

  ## State Updates
  - Updating participant state
  - Updating participant hand state

  ## State Checks
  - Checking if all players have acted
  - Checking for runout scenarios (all-in situations)
  - Checking sitting out status

  ## Round Completion
  - Orchestrating post-action flow (complete round or select next player)
  """

  # =============================================================================
  # PARTICIPANT LOOKUPS
  # =============================================================================

  @doc "Finds a participant by their ID."
  def find_participant_by_id(participants, participant_id) do
    Enum.find(participants, &(&1.id == participant_id))
  end

  @doc "Finds the index of a participant in the participants list."
  def find_participant_index(participants, participant_id) do
    Enum.find_index(participants, &(&1.id == participant_id))
  end

  @doc "Finds a participant hand by position (dealer, small_blind, big_blind, etc.)."
  def find_participant_hand_by_position(participant_hands, position) do
    Enum.find(participant_hands, &(&1.position == position))
  end

  @doc "Finds a participant by their table position."
  def find_participant_by_position(table, position) do
    hand = find_participant_hand_by_position(table.participant_hands, position)
    find_participant_by_id(table.participants, hand.participant_id)
  end

  @doc "Finds the index of a participant by their table position."
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

  @doc "Finds the current participant to act based on round state."
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

  @doc "Finds the next participant who should act after the current one."
  def find_next_participant_to_act(table) do
    participant_to_act = find_participant_to_act(table)
    participant_index = find_participant_index(table.participants, participant_to_act.id)

    find_next_active_participant(table.participants, participant_index)
  end

  defp find_next_active_participant(participants, start_index) do
    total = length(participants)

    indices = for offset <- 1..total, do: rem(start_index + offset, total)

    Enum.find_value(indices, fn index ->
      participant = Enum.at(participants, index)

      if participant.status == :active and participant.chips > 0 do
        participant
      end
    end)
  end

  @doc "Finds the next dealer button participant (rotates clockwise)."
  def find_dealer_button_participant(table) do
    if is_nil(table.dealer_button_id) do
      hd(table.participants)
    else
      dealer_index = find_participant_index(table.participants, table.dealer_button_id)
      next_dealer_index = next_participant_index(dealer_index, length(table.participants))

      Enum.at(table.participants, next_dealer_index)
    end
  end

  # =============================================================================
  # PARTICIPANT FILTERS AND UPDATES
  # =============================================================================

  @doc "Filters participants with :active status (not busted)."
  def filter_active_participants(participants) do
    Enum.filter(participants, &(&1.status == :active))
  end

  @doc """
  Filters participants who are active and not sitting out (eligible to play in hand).
  """
  def filter_playing_participants(participants) do
    Enum.filter(participants, &(&1.status == :active and not &1.is_sitting_out))
  end

  @doc "Updates a participant's state using the given function."
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

  @doc "Updates a participant hand's state using the given function."
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

  # =============================================================================
  # STATE CHECKS
  # =============================================================================

  @doc "Returns true if all participants have acted this round."
  def all_acted?(table) do
    acted_participant_ids = table.round.acted_participant_ids

    table.participants |> Enum.all?(fn participant -> participant.id in acted_participant_ids end)
  end

  @doc "Returns true if all but one participant has folded."
  def all_folded_except_one_participant?(table) do
    count_of_participant_hands = length(table.participant_hands)

    count_of_folded_participant_hands =
      table.participant_hands |> Enum.filter(fn hand -> hand.status in [:folded] end) |> length()

    count_of_participant_hands - count_of_folded_participant_hands <= 1
  end

  @doc "Returns true if this is a runout scenario (multiple players, but only one can act)."
  def runout?(table) do
    hands_in_play = Enum.reject(table.participant_hands, &(&1.status == :folded))

    hands_that_can_act =
      Enum.filter(hands_in_play, fn hand ->
        not is_all_in?(table.participants, hand.participant_id)
      end)

    length(hands_in_play) >= 2 and length(hands_that_can_act) <= 1
  end

  @doc "Returns true if only two participants are in the hand."
  def heads_up?(table) do
    length(table.participant_hands) == 2
  end

  @doc """
  Returns true if all active participants (not busted) are sitting out.
  Returns false if there are no active participants or if at least one is not sitting out.
  """
  def all_active_sitting_out?(participants) do
    active_participants = filter_active_participants(participants)

    case active_participants do
      [] -> false
      participants_list -> Enum.all?(participants_list, fn p -> p.is_sitting_out end)
    end
  end

  @doc """
  Returns true if there is at least one active participant who is not sitting out.
  """
  def has_participant_not_sitting_out?(participants) do
    active_participants = filter_active_participants(participants)
    Enum.any?(active_participants, fn p -> not p.is_sitting_out end)
  end

  # =============================================================================
  # UTILITY FUNCTIONS
  # =============================================================================

  @doc "Calculates the next participant index (wraps around)."
  def next_participant_index(current_index, total_participants) do
    rem(current_index + 1, total_participants)
  end

  # =============================================================================
  # ROUND COMPLETION ORCHESTRATION
  # =============================================================================

  alias Poker.Tables.Aggregates.Table.Pot
  alias Poker.Tables.Events.{PotsRecalculated, RoundCompleted, ParticipantToActSelected}

  @doc """
  Determines what should happen after an action: complete round or select next participant.
  Returns events to be emitted.
  """
  def handle_post_action(table) do
    all_acted? = all_acted?(table)
    all_folded_except_one? = all_folded_except_one_participant?(table)

    cond do
      all_folded_except_one? ->
        complete_round(table, :all_folded)

      all_acted? ->
        complete_round(table, :all_acted)

      true ->
        select_next_participant(table)
    end
  end

  defp complete_round(table, reason) do
    [
      %PotsRecalculated{
        table_id: table.id,
        hand_id: table.hand.id,
        pots: Pot.recalculate_pots(table.participant_hands)
      },
      %RoundCompleted{
        id: table.round.id,
        hand_id: table.hand.id,
        type: table.round.type,
        table_id: table.id,
        reason: reason
      }
    ]
  end

  defp select_next_participant(table) do
    next_participant = find_next_participant_to_act(table)

    if next_participant do
      %ParticipantToActSelected{
        table_id: table.id,
        round_id: table.round.id,
        participant_id: next_participant.id,
        timeout_seconds: table.settings.timeout_seconds,
        started_at: DateTime.utc_now()
      }
    else
      nil
    end
  end
end
