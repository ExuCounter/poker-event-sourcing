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
    ParticipantBusted
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
end
