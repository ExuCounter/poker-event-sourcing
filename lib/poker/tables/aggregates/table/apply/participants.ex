defmodule Poker.Tables.Aggregates.Table.Apply.Participants do
  @moduledoc """
  Handles participant event application.
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Aggregates.Table.Helpers
  alias Poker.Tables.Events.{TableParticipantJoined, ParticipantSatOut, ParticipantSatIn, ParticipantBusted}

  def apply(%Table{participants: participants} = table, %TableParticipantJoined{} = event) do
    new_participant = %{
      id: event.id,
      player_id: event.player_id,
      chips: event.chips,
      seat_number: event.seat_number,
      status: event.status,
      bet_this_round: event.bet_this_round,
      is_sitting_out: event.is_sitting_out,
      total_bet_this_hand: event.total_bet_this_hand,
      initial_chips: event.initial_chips
    }

    %Table{table | participants: participants ++ [new_participant]}
  end

  def apply(%Table{} = table, %ParticipantSatOut{} = event) do
    updated_participants =
      Helpers.update_participant(table, event.participant_id, &%{&1 | is_sitting_out: true})

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{} = table, %ParticipantSatIn{} = event) do
    updated_participants =
      Helpers.update_participant(table, event.participant_id, &%{&1 | is_sitting_out: false})

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{} = table, %ParticipantBusted{participant_id: participant_id}) do
    updated_participants =
      Helpers.update_participant(table, participant_id, &%{&1 | status: :busted})

    %Table{table | participants: updated_participants}
  end
end
