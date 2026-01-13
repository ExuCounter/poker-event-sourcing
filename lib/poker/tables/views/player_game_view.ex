defmodule Poker.Tables.Views.PlayerGameView do
  @moduledoc """
  Builds a player-specific game view by replaying events from the event store.
  This eliminates the need for game state projections and frontend calculations.
  """

  alias Poker.Tables.Aggregates.Table

  @doc """
  Builds a complete player game view for a specific table and player.

  Returns:
    %{
      hand_id: binary_id | nil,
      total_pot: integer,
      community_cards: [%{rank: string, suit: string}],
      hole_cards: [%{rank: string, suit: string}],
      participants: [
        %{
          id: binary_id,
          player_id: binary_id,
          chips: integer,
          position: atom | nil,
          status: atom,
          bet_this_round: integer,
          hand_status: atom | nil
        }
      ],
      current_participant_to_act_id: binary_id | nil,
      valid_actions: %{
        fold: boolean,
        check: boolean,
        call: false | %{amount: integer},
        raise: false | %{
          min: integer,
          max: integer,
          presets: [%{label: string, value: integer}]
        }
      }
    }
  """
  def build(table_id, player_id, since_event_id \\ nil) do
    # Replay events to build aggregate state
    %{latest_event_id: latest_event_id, new_events: new_events, aggregate: aggregate} =
      replay_events(table_id, since_event_id)

    # Build player-specific view
    build_view(aggregate, player_id, new_events, latest_event_id)
  end

  defp replay_events(table_id, since_event_id) do
    events =
      "table-#{table_id}"
      |> Poker.EventStore.stream_forward()
      |> Enum.to_list()

    {events_for_aggregate, new_events, latest_event_id} =
      if is_nil(since_event_id) do
        {events, events, get_latest_event_id(events)}
      else
        index = Enum.find_index(events, &(&1.event_id == since_event_id))

        events_for_aggregate = Enum.take(events, index + 1)
        new_events_raw = Enum.drop(events, index + 1)
        {events_for_aggregate, new_events_raw, since_event_id}
      end

    new_events_with_id = Enum.map(new_events, &(&1.data |> Map.put(:event_id, &1.event_id)))

    aggregate =
      events_for_aggregate
      |> Enum.map(& &1.data)
      |> Enum.reduce(%Table{}, &Table.apply(&2, &1))

    %{latest_event_id: latest_event_id, new_events: new_events_with_id, aggregate: aggregate}
  end

  defp get_latest_event_id(events) do
    case List.last(events) do
      nil -> nil
      event -> event.event_id
    end
  end

  defp build_view(aggregate, player_id, new_events, latest_event_id) do
    current_participant = find_participant_by_player_id(aggregate, player_id)

    %{
      table_status: aggregate.status,
      hand_id: get_hand_id(aggregate),
      total_pot: calculate_total_pot(aggregate),
      community_cards: aggregate.community_cards || [],
      hole_cards: get_player_hole_cards(aggregate, current_participant),
      participants: build_participants_list(aggregate),
      current_participant_to_act_id: get_participant_to_act_id(aggregate),
      valid_actions: calculate_valid_actions(aggregate, current_participant),
      small_blind: get_small_blind(aggregate),
      big_blind: get_big_blind(aggregate),
      latest_event_id: latest_event_id,
      new_events: new_events,
      payouts: aggregate.payouts || [],
      hand_status: get_hand_status(aggregate)
    }
  end

  defp get_hand_status(%{hand: %{status: status}}), do: status
  defp get_hand_status(_), do: nil

  defp get_hand_id(%{hand: %{id: id}}), do: id
  defp get_hand_id(_), do: nil

  defp calculate_total_pot(%{pots: pots}) when is_list(pots) do
    Enum.reduce(pots, 0, fn pot, acc -> acc + pot.amount end)
  end

  defp calculate_total_pot(_), do: 0

  defp calculate_total_bets(%{participant_hands: participant_hands})
       when is_list(participant_hands) do
    Enum.reduce(participant_hands, 0, fn participant_hand, acc ->
      acc + participant_hand.bet_this_round
    end)
  end

  defp calculate_total_bets(_), do: 0

  defp get_player_hole_cards(%{participant_hands: participant_hands}, %{id: participant_id})
       when is_list(participant_hands) do
    participant_hands
    |> Enum.find(&(&1.participant_id == participant_id))
    |> case do
      %{hole_cards: cards} when is_list(cards) -> cards
      _ -> []
    end
  end

  defp get_player_hole_cards(_, _), do: []

  defp build_participants_list(%{participants: participants} = aggregate)
       when is_list(participants) do
    participant_hands = Map.get(aggregate, :participant_hands, [])
    revealed_cards = Map.get(aggregate, :revealed_cards, %{})

    Enum.map(participants, fn participant ->
      participant_hand = find_participant_hand(participant_hands, participant.id)
      showdown_cards = Map.get(revealed_cards, participant.id, [])

      %{
        id: participant.id,
        player_id: participant.player_id,
        chips: participant.chips,
        position: get_participant_position(participant_hand),
        status: participant.status,
        bet_this_round: get_bet_this_round(participant_hand),
        hand_status: get_participant_hand_status(participant_hand),
        showdown_cards: showdown_cards,
        received_hole_cards?: not is_nil(get_participant_hand_hole_cards(participant_hand))
      }
    end)
  end

  defp build_participants_list(_), do: []

  defp find_participant_hand(nil, _), do: nil

  defp find_participant_hand(participant_hands, participant_id) do
    Enum.find(participant_hands, &(&1.participant_id == participant_id))
  end

  defp get_participant_position(%{position: position}), do: position
  defp get_participant_position(_), do: nil

  defp get_bet_this_round(%{bet_this_round: bet}), do: bet
  defp get_bet_this_round(_), do: 0

  defp get_participant_hand_status(%{status: status}), do: status
  defp get_participant_hand_status(_), do: nil

  defp get_participant_hand_hole_cards(%{hole_cards: hole_cards}), do: hole_cards
  defp get_participant_hand_hole_cards(_), do: nil

  defp get_participant_to_act_id(%{round: %{participant_to_act_id: id}}), do: id
  defp get_participant_to_act_id(_), do: nil

  defp find_participant_by_player_id(%{participants: participants}, player_id)
       when is_list(participants) do
    Enum.find(participants, &(&1.player_id == player_id))
  end

  defp find_participant_by_player_id(_, _), do: nil

  defp get_small_blind(%{settings: %{small_blind: sb}}), do: sb
  defp get_small_blind(_), do: 0

  defp get_big_blind(%{settings: %{big_blind: bb}}), do: bb
  defp get_big_blind(_), do: 0

  # VALID ACTIONS CALCULATION

  defp calculate_valid_actions(aggregate, nil), do: default_actions()

  defp calculate_valid_actions(aggregate, current_participant) do
    # Check if it's player's turn
    is_my_turn = is_my_turn?(aggregate, current_participant)

    unless is_my_turn and aggregate.status != :finished do
      default_actions()
    else
      current_bet = get_current_bet(aggregate)
      my_bet = get_my_bet(aggregate, current_participant)
      call_amount = max(current_bet - my_bet, 0)
      my_chips = current_participant.chips

      %{
        fold: true,
        check: call_amount == 0,
        call: if(call_amount > 0, do: %{amount: Enum.min([call_amount, my_chips])}, else: false),
        raise: calculate_raise_options(aggregate, current_participant, call_amount, my_chips)
      }
    end
  end

  defp default_actions do
    %{
      fold: false,
      check: false,
      call: false,
      raise: false
    }
  end

  defp is_my_turn?(%{round: %{participant_to_act_id: to_act_id}}, %{id: participant_id}) do
    to_act_id == participant_id
  end

  defp is_my_turn?(_, _), do: false

  defp get_current_bet(%{participant_hands: participant_hands}) when is_list(participant_hands) do
    participant_hands
    |> Enum.map(& &1.bet_this_round)
    |> Enum.max(fn -> 0 end)
  end

  defp get_current_bet(_), do: 0

  defp get_my_bet(%{participant_hands: participant_hands}, %{id: participant_id})
       when is_list(participant_hands) do
    participant_hands
    |> Enum.find(&(&1.participant_id == participant_id))
    |> case do
      %{bet_this_round: bet} -> bet
      _ -> 0
    end
  end

  defp get_my_bet(_, _), do: 0

  defp calculate_raise_options(aggregate, current_participant, call_amount, my_chips) do
    current_bet = get_current_bet(aggregate)
    big_blind = get_big_blind(aggregate)
    total_bets = calculate_total_bets(aggregate)
    my_bet = get_my_bet(aggregate, current_participant)

    # Min raise is current bet + small blind (or last raise amount)
    min_raise = max(current_bet + big_blind, big_blind)

    # Max raise is all remaining chips
    max_raise = my_chips + my_bet

    # Can only raise if we have chips beyond the call
    if my_chips > call_amount && max_raise >= min_raise do
      %{
        min: min_raise,
        max: max_raise,
        presets: build_raise_presets(total_bets, min_raise, max_raise, call_amount, current_bet)
      }
    else
      false
    end
  end

  defp build_raise_presets(pot, min_chips, max_chips, call_amount, current_bet) do
    presets =
      if pot == 0 do
        [
          %{label: "1BB", value: min_chips},
          %{label: "2BB", value: min_chips * 2},
          %{label: "3BB", value: min_chips * 3}
        ]
      else
        [
          %{label: "½ Pot", value: div(pot, 2)},
          %{label: "Pot", value: pot},
          %{label: "2x Pot", value: pot * 2},
          %{label: "3x Pot", value: pot * 3}
        ]
      end

    # Filter presets that are valid (within chip range and above current bet)
    presets
    |> Enum.filter(fn %{value: amount} ->
      amount + call_amount <= max_chips && amount > current_bet
    end)
    |> Enum.concat([%{label: "All-in", value: max_chips}])
  end
end
