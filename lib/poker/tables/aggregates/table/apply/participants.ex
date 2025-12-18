defmodule Poker.Tables.Aggregates.Table.Apply.Participants do
  @moduledoc """
  Handles participant event application.
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Aggregates.Table.Helpers

  alias Poker.Tables.Events.{
    ParticipantJoined,
    ParticipantSatOut,
    ParticipantSatIn,
    ParticipantBusted,
    ParticipantFolded,
    ParticipantChecked,
    ParticipantCalled,
    ParticipantRaised,
    ParticipantWentAllIn,
    ParticipantToActSelected
  }

  def apply(%Table{participants: participants} = table, %ParticipantJoined{} = event) do
    new_participant = %{
      id: event.id,
      player_id: event.player_id,
      chips: event.chips,
      seat_number: event.seat_number,
      status: event.status,
      is_sitting_out: event.is_sitting_out,
      initial_chips: event.initial_chips
    }

    %Table{table | participants: participants ++ [new_participant]}
  end

  def apply(%Table{} = table, %ParticipantSatOut{} = event) do
    Helpers.update_participant(table, event.participant_id, &%{&1 | is_sitting_out: true})
  end

  def apply(%Table{} = table, %ParticipantSatIn{} = event) do
    Helpers.update_participant(table, event.participant_id, &%{&1 | is_sitting_out: false})
  end

  def apply(%Table{} = table, %ParticipantBusted{participant_id: participant_id}) do
    Helpers.update_participant(table, participant_id, &%{&1 | status: :busted})
  end

  # Participant action events - Fold
  def apply(%Table{round: round} = table, %ParticipantFolded{} = event) do
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

  # Participant action events - Check
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

  # Participant action events - Call
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

  # Participant action events - Raise
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

  # Participant action events - All-in
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

  # Participant to act selected
  def apply(%Table{round: round} = table, %ParticipantToActSelected{} = event) do
    %Table{table | round: %{round | participant_to_act_id: event.participant_id}}
  end
end
