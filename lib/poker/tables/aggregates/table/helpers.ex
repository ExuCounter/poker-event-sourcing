defmodule Poker.Tables.Aggregates.Table.Helpers do
  @moduledoc """
  Shared helper functions for table aggregate operations.
  """

  # Participant finders

  def find_participant_by_id(table, participant_id) do
    Enum.find(table.participants, &(&1.id == participant_id))
  end

  def find_participant_by_seat(table, seat_number) do
    Enum.find(table.participants, &(&1.seat_number == seat_number))
  end

  def find_participant_by_position(table, position) do
    hand = find_participant_hand_by_position(table, position)
    find_participant_by_id(table, hand.participant_id)
  end

  def find_participant_hand_by_position(table, position) do
    Enum.find(table.participant_hands, &(&1.position == position))
  end

  def find_participant_to_act(%{round: %{type: :pre_flop, acted_participant_ids: []}} = table) do
    big_blind_participant = find_participant_by_position(table, :big_blind)
    active_participants = filter_active_participants(table.participants)

    seat_number = next_seat(big_blind_participant.seat_number, length(table.participants))

    find_participant_by_seat(table, seat_number)
  end

  def find_participant_to_act(%{participants: participants, round: %{participant_to_act_id: participant_to_act_id}}) do
    Enum.find(participants, &(&1.id == participant_to_act_id))
  end

  def find_next_participant_to_act(table) do
    participant_to_act = find_participant_to_act(table)
    active_participants = filter_active_participants(table.participants)

    next_participant_to_act_seat_number =
      next_seat(participant_to_act.seat_number, length(active_participants))

    find_participant_by_seat(table, next_participant_to_act_seat_number)
  end

  def find_dealer_button_participant(table) do
    if is_nil(table.dealer_button_id) do
      hd(table.participants)
    else
      dealer_button_participant = find_participant_by_id(table, table.dealer_button_id)
      seat_number = next_seat(dealer_button_participant.seat_number, length(table.participants))

      find_participant_by_seat(table, seat_number)
    end
  end

  # Participant filters and updates

  def filter_active_participants(participants) do
    Enum.filter(participants, &(&1.status == :active))
  end

  def update_participant(table, participant_id, fun) when is_function(fun, 1) do
    Enum.map(table.participants, fn
      %{id: ^participant_id} = participant ->
        fun.(participant)

      participant ->
        participant
    end)
  end

  def update_participant_hand(table, participant_id, fun) when is_function(fun, 1) do
    Enum.map(table.participant_hands, fn
      %{participant_id: ^participant_id} = participant_hand ->
        fun.(participant_hand)

      participant_hand ->
        participant_hand
    end)
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
    Enum.all?(table.participant_hands, fn hand -> hand.status in [:all_in, :folded] end)
  end

  def heads_up?(table) do
    length(table.participant_hands) == 2
  end

  # Utility functions

  def next_seat(current_seat, total_seats) do
    rem(current_seat, total_seats) + 1
  end

  def suit_abbreviation(suit) do
    %{hearts: :h, diamonds: :d, clubs: :c, spades: :s} |> Map.get(suit)
  end

  def format_to_tuple(cards) do
    cards
    |> Enum.map(fn card -> {card.rank, suit_abbreviation(card.suit)} end)
    |> List.to_tuple()
  end
end
