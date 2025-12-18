defmodule Poker.Tables.Aggregates.Table.Handlers.Participants do
  @moduledoc """
  Handles participant-related operations for poker tables.
  Manages joining, sitting out, and sitting in.
  """

  alias Poker.Tables.Commands.{
    JoinTableParticipant,
    SitOutParticipant,
    SitInParticipant,
    ParticipantFold,
    ParticipantCheck,
    ParticipantCall,
    ParticipantRaise,
    ParticipantAllIn
  }

  alias Poker.Tables.Events.{
    ParticipantJoined,
    ParticipantSatOut,
    ParticipantSatIn,
    ParticipantFolded,
    ParticipantChecked,
    ParticipantCalled,
    ParticipantRaised,
    ParticipantWentAllIn
  }

  alias Poker.Tables.Aggregates.Table.Helpers

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

  def handle(table, %ParticipantFold{} = command) do
    participant = Helpers.find_participant_to_act(table)

    participant_hand =
      Enum.find(table.participant_hands, fn hand -> hand.participant_id == participant.id end)

    %ParticipantFolded{
      id: participant_hand.id,
      participant_id: command.participant_id,
      table_hand_id: table.hand.id,
      table_id: table.id,
      status: :folded,
      round: table.round.type
    }
  end

  def handle(table, %ParticipantCheck{} = command) do
    participant = Helpers.find_participant_to_act(table)

    participant_hand =
      Enum.find(table.participant_hands, fn hand -> hand.participant_id == participant.id end)

    %ParticipantChecked{
      id: participant_hand.id,
      participant_id: command.participant_id,
      table_hand_id: table.hand.id,
      table_id: table.id,
      status: :playing,
      round: table.round.type
    }
  end

  def handle(table, %ParticipantCall{} = command) do
    participant = Helpers.find_participant_to_act(table)

    last_bet_amount =
      table.participant_hands
      |> Enum.map(& &1.bet_this_round)
      |> Enum.max()

    participant_hand =
      Enum.find(table.participant_hands, fn hand -> hand.participant_id == participant.id end)

    call_amount =
      [last_bet_amount - participant_hand.bet_this_round, participant.chips]
      |> Enum.filter(&(&1 >= 0))
      |> Enum.min()

    if participant.chips < call_amount do
      {:error, :insufficient_chips}
    else
      %ParticipantCalled{
        id: participant_hand.id,
        participant_id: command.participant_id,
        table_hand_id: table.hand.id,
        table_id: table.id,
        status: :playing,
        amount: call_amount,
        round: table.round.type
      }
    end
  end

  def handle(table, %ParticipantRaise{} = command) do
    participant = Helpers.find_participant_to_act(table)

    participant_hand =
      Enum.find(table.participant_hands, fn hand -> hand.participant_id == participant.id end)

    raise_amount = command.amount - participant_hand.bet_this_round

    if participant.chips < raise_amount do
      {:error, :insufficient_chips}
    else
      if participant.chips == raise_amount do
        %ParticipantWentAllIn{
          id: participant_hand.id,
          participant_id: command.participant_id,
          table_hand_id: table.hand.id,
          table_id: table.id,
          status: :all_in,
          amount: participant.chips,
          round: table.round.type
        }
      else
        %ParticipantRaised{
          id: participant_hand.id,
          participant_id: command.participant_id,
          table_hand_id: table.hand.id,
          table_id: table.id,
          status: :playing,
          amount: raise_amount,
          round: table.round.type
        }
      end
    end
  end

  def handle(table, %ParticipantAllIn{} = command) do
    participant = Helpers.find_participant_to_act(table)

    participant_hand =
      Enum.find(table.participant_hands, fn hand -> hand.participant_id == participant.id end)

    %ParticipantWentAllIn{
      id: participant_hand.id,
      participant_id: command.participant_id,
      table_hand_id: table.hand.id,
      table_id: table.id,
      status: :all_in,
      amount: participant.chips,
      round: table.round.type
    }
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
