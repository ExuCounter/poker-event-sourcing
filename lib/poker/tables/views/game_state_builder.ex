defmodule Poker.Tables.Views.GameStateBuilder do
  @moduledoc """
  Shared state-building logic for poker game views.

  This module extracts the core logic of replaying events and building
  player-specific game state. It supports both live game and replay modes
  with configurable card visibility and action calculation.
  """

  alias Poker.Tables.Aggregates.Table

  @doc """
  Builds a complete player game view for a specific table and player.

  ## Options
    * `:visibility_mode` - `:live` or `:replay` (default: `:live`)
    * `:calculate_actions` - Whether to calculate valid actions (default: `true`)
    * `:since_version` - Stream version for incremental updates (default: `nil`)

  ## Visibility Modes
    * `:live` - Only shows current player's hole cards, hides opponent cards
    * `:replay` - Shows current player's cards + revealed showdown cards for opponents
  """
  def build(table_id, player_id, opts \\ []) do
    visibility_mode = Keyword.get(opts, :visibility_mode, :live)
    calculate_actions = Keyword.get(opts, :calculate_actions, true)
    since_version = Keyword.get(opts, :since_version)

    # Replay events to build aggregate state
    %{latest_version: latest_version, aggregate: aggregate} =
      replay_events(table_id, since_version)

    build_view(aggregate, player_id, latest_version,
      visibility_mode: visibility_mode,
      calculate_actions: calculate_actions
    )
  end

  @doc """
  Replays events from EventStore to build aggregate state.

  Supports incremental updates when `since_version` is provided.
  Returns map with aggregate, new events, and latest stream version.
  """
  def replay_events(table_id, since_version \\ nil) do
    stream_id = "table-#{table_id}"

    if is_nil(since_version) do
      with {:ok, snapshot} <- Commanded.EventStore.read_snapshot(Poker.App, stream_id) do
        events_after_snapshot =
          Poker.App
          |> Commanded.EventStore.stream_forward(stream_id, snapshot.source_version + 1)
          |> Enum.to_list()

        dbg(snapshot.source_version)

        aggregate =
          events_after_snapshot
          |> Enum.map(& &1.data)
          |> Enum.reduce(snapshot.data, &Table.apply(&2, &1))

        dbg(aggregate.participants)

        %{aggregate: aggregate, latest_version: get_latest_version(events_after_snapshot)}
      else
        {:error, :snapshot_not_found} ->
          all_events =
            Poker.App
            |> Commanded.EventStore.stream_forward(stream_id)
            |> Enum.to_list()

          aggregate =
            all_events
            |> Enum.map(& &1.data)
            |> Enum.reduce(%Table{}, &Table.apply(&2, &1))

          %{aggregate: aggregate, latest_version: get_latest_version(all_events)}
      end
    else
      hand_history = find_hand_history_for_version(table_id, since_version)

      if hand_history do
        initial_aggregate = :erlang.binary_to_term(hand_history.initial_state)

        hand_events =
          Commanded.EventStore.stream_forward(
            Poker.App,
            stream_id,
            hand_history.start_version
          )
          |> Enum.take(since_version - hand_history.start_version + 1)
          |> Enum.to_list()

        hand_events = Enum.to_list(hand_events)

        aggregate =
          hand_events
          |> Enum.map(& &1.data)
          |> Enum.reduce(initial_aggregate, &Table.apply(&2, &1))

        %{aggregate: aggregate, latest_version: since_version}
      else
        all_events =
          Commanded.EventStore.stream_forward(
            Poker.App,
            stream_id,
            0
          )
          |> Enum.to_list()

        all_events = Enum.to_list(all_events)

        aggregate =
          all_events
          |> Enum.map(& &1.data)
          |> Enum.reduce(%Table{}, &Table.apply(&2, &1))

        %{aggregate: aggregate, latest_version: since_version}
      end
    end
  end

  @doc """
  Transforms aggregate state into player-specific view.

  Applies visibility rules and optionally calculates valid actions.
  """
  def build_view(aggregate, player_id, latest_version, opts \\ []) do
    visibility_mode = Keyword.get(opts, :visibility_mode, :live)
    calculate_actions = Keyword.get(opts, :calculate_actions, true)

    current_participant = find_participant_by_player_id(aggregate, player_id)

    dbg(aggregate.status)

    %{
      table_status: aggregate.status,
      hand_id: get_hand_id(aggregate),
      total_pot: calculate_total_pot(aggregate),
      community_cards:
        if aggregate.status == :paused do
          []
        else
          aggregate.community_cards
        end,
      hole_cards: get_player_hole_cards(aggregate, current_participant),
      participants: build_participants_list(aggregate, player_id, visibility_mode),
      valid_actions:
        if calculate_actions do
          calculate_valid_actions(aggregate, current_participant)
        else
          default_actions()
        end,
      latest_version: latest_version,
      hand_status: get_hand_status(aggregate),
      timeout_seconds: get_timeout_seconds(aggregate),
      current_turn: get_current_turn(aggregate),
      timeout_info: build_timeout_info(aggregate)
    }
  end

  # Private helpers

  defp get_latest_version(events) do
    case List.last(events) do
      nil -> nil
      event -> event.stream_version
    end
  end

  defp find_hand_history_for_version(table_id, version) do
    import Ecto.Query

    from(h in Poker.Tables.Projections.HandHistory,
      where:
        h.table_id == ^table_id and
          h.start_version <= ^version and
          (is_nil(h.end_version) or h.end_version >= ^version),
      limit: 1
    )
    |> Poker.Repo.one()
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

  defp build_participants_list(
         %{participants: participants, status: table_status} = aggregate,
         current_player_id,
         visibility_mode
       )
       when is_list(participants) do
    participant_hands = Map.get(aggregate, :participant_hands, [])

    Enum.map(participants, fn participant ->
      participant_hand = find_participant_hand(participant_hands, participant.id)

      # Determine hole cards based on visibility mode
      hole_cards =
        case {table_status, visibility_mode, participant.player_id} do
          {:paused, _visibility_mode, _current_player_id} ->
            []

          # Live mode: only show current player's cards
          {_table_status, :live, ^current_player_id} ->
            get_player_hole_cards(aggregate, participant)

          # Replay mode: show current player's cards OR revealed showdown cards
          {_table_status, :replay, ^current_player_id} ->
            get_player_hole_cards(aggregate, participant)

          _ ->
            player_cards = get_player_hole_cards(aggregate, participant)

            if player_cards == [] do
              []
            else
              [nil, nil]
            end
        end

      %{
        id: participant.id,
        player_id: participant.player_id,
        chips: participant.chips,
        position: get_participant_position(participant_hand),
        status: participant.status,
        bet_this_round: get_bet_this_round(participant_hand),
        hand_status: get_participant_hand_status(participant_hand),
        hole_cards: hole_cards,
        is_sitting_out: participant.is_sitting_out
      }
    end)
  end

  defp build_participants_list(
         _aggregate,
         _current_player_id,
         _visibility_mode
       ) do
    []
  end

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

  defp find_participant_by_player_id(%{participants: participants}, player_id)
       when is_list(participants) do
    Enum.find(participants, &(&1.player_id == player_id))
  end

  defp find_participant_by_player_id(_, _), do: nil

  defp get_small_blind(%{settings: %{small_blind: sb}}), do: sb
  defp get_small_blind(_), do: 0

  defp get_big_blind(%{settings: %{big_blind: bb}}), do: bb
  defp get_big_blind(_), do: 0

  defp get_timeout_seconds(%{settings: %{timeout_seconds: timeout}}), do: timeout
  defp get_timeout_seconds(_), do: nil

  defp get_current_turn(%{round: %{participant_to_act_id: participant_id}})
       when not is_nil(participant_id) do
    %{
      participant_id: participant_id
    }
  end

  defp get_current_turn(_), do: nil

  defp build_timeout_info(%{round: %{started_at: started_at, timeout_seconds: timeout_seconds}})
       when not is_nil(started_at) and not is_nil(timeout_seconds) do
    %{
      started_at: started_at,
      timeout_seconds: timeout_seconds
    }
  end

  defp build_timeout_info(_), do: nil

  # VALID ACTIONS CALCULATION

  defp calculate_valid_actions(_aggregate, nil), do: default_actions()

  defp calculate_valid_actions(aggregate, current_participant) do
    # Check if it's player's turn
    is_my_turn = is_my_turn?(aggregate, current_participant)

    unless is_my_turn and aggregate.status not in [:finished, :paused] do
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
  end
end
