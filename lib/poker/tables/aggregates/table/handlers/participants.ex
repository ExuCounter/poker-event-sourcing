defmodule Poker.Tables.Aggregates.Table.Handlers.Participants do
  @moduledoc """
  Handles participant-related operations for poker tables.
  Manages joining, sitting out, and sitting in.
  """

  alias Poker.Tables.Commands.{JoinTableParticipant, SitOutParticipant, SitInParticipant}
  alias Poker.Tables.Events.{ParticipantJoined, ParticipantSatOut, ParticipantSatIn}

  @max_players %{
    six_max: 6
  }

  @doc """
  Handles participant commands.
  """
  def handle(%{status: :live}, %JoinTableParticipant{}),
    do: {:error, :table_already_started}

  def handle(table, %JoinTableParticipant{} = command) do
    max_players = Map.fetch!(@max_players, table.settings.table_type)

    with :ok <- validate_not_already_joined(table.participants, command.player_id),
         :ok <- validate_seat_available(table.participants, max_players) do
      seat_number = length(table.participants) + 1

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
        seat_number: seat_number,
        is_sitting_out: false,
        status: :active
      }
    end
  end

  def handle(table, %SitOutParticipant{} = command) do
    participant = Enum.find(table.participants, &(&1.id == command.participant_id))

    if participant.is_sitting_out do
      {:error, :already_sat_out}
    else
      %ParticipantSatOut{
        participant_id: command.participant_id,
        table_id: command.table_id
      }
    end
  end

  def handle(table, %SitInParticipant{} = command) do
    participant = Enum.find(table.participants, &(&1.id == command.participant_id))

    if participant && participant.is_sitting_out do
      %ParticipantSatIn{
        participant_id: command.participant_id,
        table_id: command.table_id
      }
    else
      if participant do
        {:error, :already_sat_in}
      else
        # Participant doesn't exist, create sit in event anyway
        %ParticipantSatIn{
          participant_id: command.participant_id,
          table_id: command.table_id
        }
      end
    end
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
end
