defmodule PokerWeb.PlayerLive.GameHelpers do
  @moduledoc """
  Helper functions for poker game UI logic.
  Calculates button states, amounts, and determines valid actions.
  """

  @doc """
  Determines which action buttons should be enabled for the current player.
  Returns a map with button states and calculated amounts.
  """
  def calculate_action_state(assigns) do
    %{
      is_my_turn: is_my_turn?(assigns),
      can_check: can_check?(assigns),
      can_call: can_call?(assigns),
      can_raise: can_raise?(assigns),
      call_amount: calculate_call_amount(assigns),
      pot_size: calculate_pot_size(assigns),
      my_chips: get_my_chips(assigns),
      current_bet: get_current_bet(assigns),
      bet_this_round: get_bet_this_round(assigns)
    }
  end

  defp get_bet_this_round(%{
         participant_hands: participant_hands,
         current_participant_id: current_participant_id
       }) do
    my_participant_hand =
      Enum.find(participant_hands, &(&1.participant_id == current_participant_id))

    if my_participant_hand do
      my_participant_hand.bet_this_round
    else
      0
    end
  end

  defp is_my_turn?(%{
         participant_to_act_id: participant_to_act_id,
         current_participant_id: current_participant_id
       })
       when not is_nil(participant_to_act_id) and not is_nil(current_participant_id) do
    participant_to_act_id == current_participant_id
  end

  defp is_my_turn?(_assigns), do: false

  defp can_check?(assigns) do
    is_my_turn?(assigns) && calculate_call_amount(assigns) == 0
  end

  defp can_call?(assigns) do
    is_my_turn?(assigns) && calculate_call_amount(assigns) > 0
  end

  defp can_raise?(assigns) do
    my_chips = get_my_chips(assigns)
    call_amount = calculate_call_amount(assigns)
    is_my_turn?(assigns) && my_chips > call_amount
  end

  defp calculate_call_amount(%{
         current_round: current_round,
         participant_hands: participant_hands,
         current_participant_id: current_participant_id
       })
       when not is_nil(current_round) and not is_nil(current_participant_id) do
    # Find the highest bet in the current round
    highest_bet = get_highest_bet(participant_hands)

    # Find current participant's bet this round
    my_participant_hand =
      Enum.find(participant_hands, &(&1.participant_id == current_participant_id))

    my_bet =
      if my_participant_hand do
        my_participant_hand.bet_this_round
      else
        0
      end

    # Call amount is the difference between highest bet and my bet
    max(highest_bet - my_bet, 0)
  end

  defp calculate_call_amount(_assigns), do: 0

  defp calculate_pot_size(%{pots: pots}) do
    Enum.reduce(pots, 0, fn pot, acc -> acc + pot.amount end)
  end

  defp get_my_chips(%{
         participants: participants,
         current_participant_id: current_participant_id
       })
       when not is_nil(current_participant_id) do
    participant = Enum.find(participants, &(&1.id == current_participant_id))
    (participant && participant.chips) || 0
  end

  defp get_my_chips(_assigns), do: 0

  defp get_current_bet(%{
         current_round: current_round,
         participant_hands: participant_hands
       })
       when not is_nil(current_round) do
    get_highest_bet(participant_hands)
  end

  defp get_current_bet(_assigns), do: 0

  defp get_highest_bet([]), do: 0

  # Helper function to get the highest bet in the current round
  defp get_highest_bet(participant_hands) when is_list(participant_hands) do
    participant_hands
    |> Enum.map(& &1.bet_this_round)
    |> Enum.max()
  end

  @doc """
  Generates raise preset amounts based on pot and stack.
  Returns a list of {label, amount} tuples.
  """
  def calculate_raise_presets(action_state) do
    pot = action_state.pot_size
    my_chips = action_state.my_chips
    call_amount = action_state.call_amount
    current_bet = action_state.current_bet

    presets = [
      {"1/2 Pot", div(pot, 2)},
      {"Pot", pot},
      {"2x Pot", pot * 2},
      {"3x Pot", pot * 3},
      {"100%", my_chips}
    ]

    # Filter out presets that exceed available chips or are below minimum
    Enum.filter(presets, fn {_label, amount} ->
      amount + call_amount <= my_chips && amount > current_bet
    end)
  end

  @doc """
  Finds participant by participant_id and returns player info merged with participant data.
  """
  def get_participant_info(participant_hand, participants, lobby) do
    participant = Enum.find(participants, &(&1.id == participant_hand.participant_id))

    if participant do
      lobby_participant =
        Enum.find(lobby.participants, &(&1.player_id == participant.player_id))

      %{
        participant_id: participant.id,
        player_id: participant.player_id,
        email: (lobby_participant && lobby_participant.email) || "Unknown",
        chips: participant.chips,
        status: participant.status,
        hand_status: participant_hand.status,
        hole_cards: participant_hand.hole_cards || [],
        position: participant_hand.position
      }
    else
      # Fallback if participant not found
      %{
        participant_id: participant_hand.participant_id,
        player_id: nil,
        email: "Unknown",
        chips: 0,
        status: :unknown,
        hand_status: participant_hand.status,
        hole_cards: participant_hand.hole_cards || [],
        position: participant_hand.position
      }
    end
  end

  @doc """
  Filters hole cards - only shows cards for the current user.
  Returns list of participant hands with filtered cards.
  """
  def filter_hole_cards(participant_hands, current_user_id, participants) do
    Enum.map(participant_hands, fn hand ->
      participant = Enum.find(participants, &(&1.id == hand.participant_id))

      if participant && participant.player_id == current_user_id do
        hand
      else
        %{hand | hole_cards: []}
      end
    end)
  end

  @doc """
  Calculates the minimum and maximum raise amounts.
  Returns {min_raise, max_raise}.
  """
  def calculate_raise_limits(action_state, small_blind) do
    current_bet = action_state.current_bet
    my_chips = action_state.my_chips

    # Minimum raise is typically current bet + the last raise amount
    # For simplicity, we use current_bet + 1 as minimum
    min_raise = max(current_bet + small_blind, small_blind)

    max_raise = my_chips + action_state.bet_this_round

    {min_raise, max_raise}
  end
end
