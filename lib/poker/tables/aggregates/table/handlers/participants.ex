defmodule Poker.Tables.Aggregates.Table.Handlers.Participants do
  @moduledoc """
  Handles all participant-related operations for poker tables.

  This module handles:
  - Joining/leaving tables
  - Sitting out/in
  - Betting actions (fold, check, call, raise, all-in)
  - Timeouts

  For betting actions during a hand, this module:
  1. Validates it's the participant's turn
  2. Creates the action event
  3. Handles round completion (via Helpers.handle_post_action/1)
  """

  alias Poker.Tables.Commands.{
    JoinTableParticipant,
    SitOutParticipant,
    SitInParticipant,
    ParticipantFold,
    ParticipantCheck,
    ParticipantCall,
    ParticipantRaise,
    ParticipantAllIn,
    TimeoutParticipant,
    LeaveTable
  }

  alias Poker.Tables.Events.{
    ParticipantJoined,
    ParticipantSatOut,
    ParticipantSatIn,
    ParticipantFolded,
    ParticipantChecked,
    ParticipantCalled,
    ParticipantRaised,
    ParticipantWentAllIn,
    ParticipantTimedOut,
    ParticipantLeft
  }

  alias Poker.Tables.Aggregates.Table.Helpers

  @max_players %{
    six_max: 6
  }

  # =============================================================================
  # JOIN TABLE
  # =============================================================================

  # Cannot join finished tables
  def handle(%{status: :finished}, %JoinTableParticipant{}),
    do: {:error, :cannot_join_finished_table}

  # Tournaments cannot be joined after they start
  def handle(%{status: :live, game_mode: :tournament}, %JoinTableParticipant{}),
    do: {:error, :cannot_join_started_tournament}

  # Cash games can be joined anytime (waiting or live)
  def handle(table, %JoinTableParticipant{} = command) do
    max_players = Map.fetch!(@max_players, table.settings.table_type)

    with :ok <- validate_not_already_joined(table.participants, command.player_id),
         :ok <- validate_seat_available(table.participants, max_players) do
      initial_chips =
        if is_nil(command.starting_stack) do
          table.settings.starting_stack
        else
          command.starting_stack
        end

      %ParticipantJoined{
        id: command.participant_id,
        player_id: command.player_id,
        table_id: command.table_id,
        chips: initial_chips,
        initial_chips: initial_chips,
        is_sitting_out: false,
        status: :active,
        nickname: command.nickname
      }
    end
  end

  # =============================================================================
  # SIT OUT / SIT IN
  # =============================================================================

  def handle(table, %SitOutParticipant{player_id: player_id} = command) do
    participant = Enum.find(table.participants, fn p -> p.player_id == player_id end)

    cond do
      is_nil(participant) ->
        {:error, :participant_not_found}

      participant.is_sitting_out ->
        {:error, :already_sat_out}

      in_active_hand?(table, participant) ->
        sit_out_during_hand(table, command, participant)

      true ->
        %ParticipantSatOut{
          participant_id: participant.id,
          table_id: command.table_id
        }
    end
  end

  def handle(table, %SitInParticipant{player_id: player_id} = command) do
    participant = Enum.find(table.participants, fn p -> p.player_id == player_id end)

    cond do
      is_nil(participant) ->
        {:error, :participant_not_found}

      not participant.is_sitting_out ->
        {:error, :not_sitting_out}

      true ->
        %ParticipantSatIn{
          participant_id: participant.id,
          table_id: command.table_id
        }
    end
  end

  # =============================================================================
  # LEAVE TABLE (Cash Games Only)
  # =============================================================================

  # Cannot leave tournaments
  def handle(%{game_mode: :tournament}, %LeaveTable{}),
    do: {:error, :cannot_leave_tournament}

  # Cannot leave finished tables
  def handle(%{status: :finished}, %LeaveTable{}),
    do: {:error, :table_already_finished}

  def handle(table, %LeaveTable{player_id: player_id} = command) do
    participant = Enum.find(table.participants, fn p -> p.player_id == player_id end)

    cond do
      is_nil(participant) ->
        {:error, :participant_not_found}

      in_active_hand?(table, participant) ->
        leave_during_hand(table, command, participant)

      true ->
        %ParticipantLeft{
          participant_id: participant.id,
          player_id: participant.player_id,
          table_id: command.table_id,
          chips: participant.chips
        }
    end
  end

  # =============================================================================
  # TIMEOUT
  # =============================================================================

  def handle(%{hand: nil}, %TimeoutParticipant{}),
    do: {:error, :no_active_hand}

  def handle(
        %{round: %{participant_to_act_id: participant_to_act_id, id: round_id}},
        %TimeoutParticipant{participant_id: participant_id, round_id: command_round_id}
      )
      when participant_to_act_id != participant_id or round_id != command_round_id do
    {:error, :stale_timeout}
  end

  def handle(table, %TimeoutParticipant{} = command) do
    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn _table ->
      [
        %ParticipantTimedOut{
          id: UUIDv7.generate(),
          table_id: command.table_id,
          participant_id: command.participant_id,
          round_id: command.round_id
        },
        %ParticipantFolded{
          participant_id: command.participant_id,
          hand_id: table.hand.id,
          table_id: command.table_id,
          status: :folded,
          round: table.round.type,
          folded_at: DateTime.utc_now()
        },
        %ParticipantSatOut{
          table_id: command.table_id,
          participant_id: command.participant_id
        }
      ]
    end)
    |> Commanded.Aggregate.Multi.execute(&Helpers.handle_post_action/1)
  end

  # =============================================================================
  # BETTING ACTIONS (Fold, Check, Call, Raise, All-In)
  # =============================================================================

  def handle(
        %{round: %{participant_to_act_id: participant_to_act_id}} = table,
        %cmd{player_id: player_id} = command
      )
      when cmd in [
             ParticipantFold,
             ParticipantCheck,
             ParticipantCall,
             ParticipantRaise,
             ParticipantAllIn
           ] do
    participant = Enum.find(table.participants, fn p -> p.player_id == player_id end)

    cond do
      is_nil(participant) ->
        {:error, :participant_not_found}

      participant.id != participant_to_act_id ->
        {:error,
         %{status: :not_participants_turn, message: "It's not this participant's turn to act"}}

      true ->
        table
        |> Commanded.Aggregate.Multi.new()
        |> Commanded.Aggregate.Multi.execute(fn tbl -> build_action_event(tbl, command) end)
        |> Commanded.Aggregate.Multi.execute(&Helpers.handle_post_action/1)
    end
  end

  # =============================================================================
  # EVENT BUILDERS (Private)
  # =============================================================================

  defp build_action_event(table, %ParticipantFold{player_id: player_id}) do
    participant = Enum.find(table.participants, fn p -> p.player_id == player_id end)

    %ParticipantFolded{
      participant_id: participant.id,
      hand_id: table.hand.id,
      table_id: table.id,
      status: :folded,
      round: table.round.type,
      folded_at: DateTime.utc_now()
    }
  end

  defp build_action_event(table, %ParticipantCheck{player_id: player_id}) do
    participant = Enum.find(table.participants, fn p -> p.player_id == player_id end)
    participant_hand = find_participant_hand(table, participant.id)

    current_bet = get_current_bet(table)
    my_bet = participant_hand.bet_this_round
    call_amount = current_bet - my_bet

    if call_amount > 0 do
      {:error, %{status: :invalid_action, message: "Cannot check when there is a bet to call"}}
    else
      %ParticipantChecked{
        participant_id: participant.id,
        hand_id: table.hand.id,
        table_id: table.id,
        status: :playing,
        round: table.round.type
      }
    end
  end

  defp build_action_event(table, %ParticipantCall{player_id: player_id}) do
    participant = Enum.find(table.participants, fn p -> p.player_id == player_id end)
    participant_hand = find_participant_hand(table, participant.id)

    last_bet_amount =
      table.participant_hands
      |> Enum.map(& &1.bet_this_round)
      |> Enum.max()

    call_amount =
      [last_bet_amount - participant_hand.bet_this_round, participant.chips]
      |> Enum.filter(&(&1 >= 0))
      |> Enum.min()

    %ParticipantCalled{
      participant_id: participant.id,
      hand_id: table.hand.id,
      table_id: table.id,
      status: :playing,
      amount: call_amount,
      round: table.round.type
    }
  end

  defp build_action_event(table, %ParticipantRaise{player_id: player_id, amount: amount}) do
    participant = Enum.find(table.participants, fn p -> p.player_id == player_id end)
    participant_hand = find_participant_hand(table, participant.id)

    current_bet = get_current_bet(table)
    my_bet = participant_hand.bet_this_round
    raise_amount = amount - my_bet

    # Minimum raise: must be at least current_bet + big_blind
    min_raise_to = current_bet + table.settings.big_blind

    cond do
      # Cannot bet more chips than you have
      raise_amount > participant.chips ->
        {:error,
         %{status: :invalid_action, message: "Cannot raise more than your total chips"}}

      # If using all remaining chips, convert to all-in (valid regardless of minimum)
      raise_amount == participant.chips ->
        %ParticipantWentAllIn{
          participant_id: participant.id,
          hand_id: table.hand.id,
          table_id: table.id,
          status: :playing,
          amount: participant.chips,
          round: table.round.type
        }

      # Check minimum raise requirement
      amount < min_raise_to ->
        {:error,
         %{
           status: :invalid_action,
           message: "Raise must be at least #{min_raise_to}"
         }}

      true ->
        %ParticipantRaised{
          participant_id: participant.id,
          hand_id: table.hand.id,
          table_id: table.id,
          status: :playing,
          amount: raise_amount,
          round: table.round.type
        }
    end
  end

  defp build_action_event(table, %ParticipantAllIn{player_id: player_id}) do
    participant = Enum.find(table.participants, fn p -> p.player_id == player_id end)

    %ParticipantWentAllIn{
      participant_id: participant.id,
      hand_id: table.hand.id,
      table_id: table.id,
      status: :playing,
      amount: participant.chips,
      round: table.round.type
    }
  end

  # =============================================================================
  # PRIVATE HELPERS
  # =============================================================================

  defp in_active_hand?(table, participant) do
    table.hand != nil and
      table.participant_hands != nil and
      Enum.any?(table.participant_hands, fn hand ->
        hand.participant_id == participant.id && hand.status == :playing
      end)
  end

  defp find_participant_hand(table, participant_id) do
    Enum.find(table.participant_hands, fn hand ->
      hand.participant_id == participant_id
    end)
  end

  defp get_current_bet(table) do
    table.participant_hands
    |> Enum.map(& &1.bet_this_round)
    |> Enum.max(fn -> 0 end)
  end

  defp sit_out_during_hand(table, command, participant) do
    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn _table ->
      [
        %ParticipantFolded{
          participant_id: participant.id,
          hand_id: table.hand.id,
          table_id: command.table_id,
          status: :folded,
          round: table.round.type,
          folded_at: DateTime.utc_now()
        },
        %ParticipantSatOut{
          participant_id: participant.id,
          table_id: command.table_id
        }
      ]
    end)
    |> Commanded.Aggregate.Multi.execute(&Helpers.handle_post_action/1)
  end

  defp validate_not_already_joined(participants, player_id) do
    if Enum.any?(participants, &(&1.player_id == player_id)),
      do: {:error, %{status: :unprocessable_entity, message: "Already joined to the table"}},
      else: :ok
  end

  defp validate_seat_available(participants, max_players) do
    if length(participants) < max_players,
      do: :ok,
      else: {:error, :table_full}
  end

  defp leave_during_hand(table, command, participant) do
    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn _table ->
      [
        %ParticipantFolded{
          participant_id: participant.id,
          hand_id: table.hand.id,
          table_id: command.table_id,
          status: :folded,
          round: table.round.type,
          folded_at: DateTime.utc_now()
        },
        %ParticipantLeft{
          participant_id: participant.id,
          player_id: participant.player_id,
          table_id: command.table_id,
          chips: participant.chips
        }
      ]
    end)
    |> Commanded.Aggregate.Multi.execute(&Helpers.handle_post_action/1)
  end
end
