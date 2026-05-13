defmodule Poker.Tables.Aggregates.Table.Apply.Participants do
  @moduledoc """
  Applies participant-related events to aggregate state.

  Handles the following event categories:

  ## Membership Events
  - `ParticipantJoined` - Adds a new participant to the table
  - `ParticipantSatOut` - Marks participant as sitting out
  - `ParticipantSatIn` - Marks participant as active
  - `ParticipantBusted` - Marks participant as busted (out of chips)
  - `ParticipantTimedOut` - Informational event (no state change)

  ## Betting Action Events
  - `ParticipantFolded` - Updates hand status and adds to acted list
  - `ParticipantChecked` - Adds participant to acted list
  - `ParticipantCalled` - Deducts chips, updates bets, adds to acted list
  - `ParticipantRaised` - Deducts chips, updates bets, resets acted list
  - `ParticipantWentAllIn` - Deducts chips, updates bets, adjusts acted list

  ## Turn Management
  - `ParticipantToActSelected` - Updates current participant to act
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Aggregates.Table.Helpers

  alias Poker.Tables.Events.{
    ParticipantJoined,
    ParticipantSatOut,
    ParticipantSatIn,
    ParticipantBoughtIn,
    ParticipantBuyInApplied,
    ParticipantBusted,
    ParticipantLeft,
    ParticipantFolded,
    ParticipantChecked,
    ParticipantCalled,
    ParticipantRaised,
    ParticipantWentAllIn,
    ParticipantToActSelected,
    ParticipantTimedOut
  }

  # =============================================================================
  # MEMBERSHIP EVENTS
  # =============================================================================

  @doc "Adds a new participant to the table."
  def apply(%Table{participants: participants} = table, %ParticipantJoined{} = event) do
    new_participant = %{
      id: event.id,
      player_id: event.player_id,
      nickname: event.nickname || "Player",
      chips: event.chips,
      status: event.status,
      is_sitting_out: event.is_sitting_out,
      initial_chips: event.initial_chips,
      seat_number: event.seat_number,
      pending_buyin: 0
    }

    %Table{table | participants: participants ++ [new_participant]}
  end

  # Marks participant as sitting out.
  def apply(%Table{} = table, %ParticipantSatOut{} = event) do
    Helpers.update_participant(table, event.participant_id, &%{&1 | is_sitting_out: true})
  end

  # Marks participant as active (not sitting out).
  def apply(%Table{} = table, %ParticipantSatIn{} = event) do
    Helpers.update_participant(table, event.participant_id, &%{&1 | is_sitting_out: false})
  end

  # Records pending buy-in (chips applied at next hand start).
  def apply(%Table{} = table, %ParticipantBoughtIn{} = event) do
    Helpers.update_participant(table, event.participant_id, fn p ->
      %{p | pending_buyin: p.pending_buyin + event.amount}
    end)
  end

  # Applies pending buy-in at hand start: adds chips, sits in, clears pending.
  def apply(%Table{} = table, %ParticipantBuyInApplied{} = event) do
    Helpers.update_participant(table, event.participant_id, fn p ->
      %{p | chips: p.chips + event.amount, pending_buyin: 0, is_sitting_out: false}
    end)
  end

  # Marks participant as busted (out of chips).
  def apply(%Table{} = table, %ParticipantBusted{participant_id: participant_id}) do
    Helpers.update_participant(table, participant_id, &%{&1 | status: :busted})
  end

  # Removes participant from table (cash game leave).
  # Also clears dealer_button_id if the leaving participant was the dealer.
  def apply(
        %Table{participants: participants, dealer_button_id: dealer_button_id} = table,
        %ParticipantLeft{participant_id: participant_id}
      ) do
    updated_participants = Enum.reject(participants, &(&1.id == participant_id))

    updated_dealer_button_id =
      if dealer_button_id == participant_id, do: nil, else: dealer_button_id

    %Table{table | participants: updated_participants, dealer_button_id: updated_dealer_button_id}
  end

  # Handles timeout event (informational only, no state change).
  def apply(%Table{} = table, %ParticipantTimedOut{} = _event) do
    # The actual state changes come from ParticipantFolded and ParticipantSatOut
    table
  end

  # =============================================================================
  # BETTING ACTION EVENTS
  # =============================================================================

  # Marks participant hand as folded and adds to acted list.
  def apply(%Table{round: round} = table, %ParticipantFolded{} = event) do
    updated_round = %{
      round
      | acted_participant_ids: round.acted_participant_ids ++ [event.participant_id]
    }

    table
    |> Helpers.update_participant_hand(event.participant_id, fn hand ->
      %{hand | status: event.status, folded_at: event.folded_at}
    end)
    |> Map.put(:round, updated_round)
  end

  # Adds participant to acted list (no chips change).
  def apply(%Table{round: round} = table, %ParticipantChecked{} = event) do
    updated_round = %{
      round
      | acted_participant_ids: round.acted_participant_ids ++ [event.participant_id]
    }

    table
    |> Helpers.update_participant_hand(event.participant_id, fn hand ->
      %{hand | status: event.status}
    end)
    |> Map.put(:round, updated_round)
  end

  # Deducts chips for call amount, updates bets, adds to acted list.
  def apply(%Table{round: round} = table, %ParticipantCalled{} = event) do
    updated_round = %{
      round
      | acted_participant_ids: round.acted_participant_ids ++ [event.participant_id]
    }

    table
    |> Helpers.update_participant(event.participant_id, &%{&1 | chips: &1.chips - event.amount})
    |> Helpers.update_participant_hand(event.participant_id, fn hand ->
      %{
        hand
        | bet_this_round: hand.bet_this_round + event.amount,
          total_bet_this_hand: hand.total_bet_this_hand + event.amount,
          status: event.status
      }
    end)
    |> Map.put(:round, updated_round)
  end

  # Deducts chips for raise, updates bets, resets acted list (others must act again).
  def apply(%Table{round: round} = table, %ParticipantRaised{} = event) do
    updated_round = %{
      round
      | acted_participant_ids: [event.participant_id]
    }

    table
    |> Helpers.update_participant(event.participant_id, &%{&1 | chips: &1.chips - event.amount})
    |> Helpers.update_participant_hand(event.participant_id, fn hand ->
      %{
        hand
        | bet_this_round: hand.bet_this_round + event.amount,
          total_bet_this_hand: hand.total_bet_this_hand + event.amount,
          status: event.status
      }
    end)
    |> Map.put(:round, updated_round)
  end

  # Puts participant all-in, adjusts acted list based on bet amounts.
  def apply(%Table{round: round} = table, %ParticipantWentAllIn{} = event) do
    acted_participant_ids =
      Enum.reject(round.acted_participant_ids, fn id ->
        participant_hand = Enum.find(table.participant_hands, &(&1.participant_id == id))

        participant_hand.bet_this_round < event.amount or id == event.participant_id
      end)

    updated_round = %{
      round
      | acted_participant_ids: acted_participant_ids ++ [event.participant_id]
    }

    table
    |> Helpers.update_participant(event.participant_id, &%{&1 | chips: &1.chips - event.amount})
    |> Helpers.update_participant_hand(event.participant_id, fn hand ->
      %{
        hand
        | bet_this_round: hand.bet_this_round + event.amount,
          total_bet_this_hand: hand.total_bet_this_hand + event.amount,
          status: event.status
      }
    end)
    |> Map.put(:round, updated_round)
  end

  # =============================================================================
  # TURN MANAGEMENT
  # =============================================================================

  # Updates which participant is currently to act.
  def apply(%Table{round: round} = table, %ParticipantToActSelected{} = event) do
    %Table{
      table
      | round: %{
          round
          | participant_to_act_id: event.participant_id,
            started_at: event.started_at,
            timeout_seconds: event.timeout_seconds
        }
    }
  end
end
