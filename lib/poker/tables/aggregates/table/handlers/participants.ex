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
    ParticipantWentAllIn,
    ParticipantToActSelected
  }

  alias Poker.Tables.Aggregates.Table.Helpers
  alias Poker.Tables.Aggregates.Table.Pot
  alias Poker.Tables.Events.{PotsRecalculated, RoundCompleted}

  @max_players %{
    six_max: 6
  }

  @doc """
  Handles participant commands.
  """
  def handle(%{status: status}, %JoinTableParticipant{}) when status in [:live, :finished],
    do: {:error, :cannot_join_started_or_finished_table}

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
        status: :active
      }
    end
  end

  def handle(table, %SitOutParticipant{} = command) do
    participant = Enum.find(table.participants, &(&1.player_id == command.player_id))

    if participant.is_sitting_out do
      {:error, :already_sat_out}
    else
      # Check if participant is in an active hand
      participant_hand =
        if table.hand && table.participant_hands do
          Enum.find(table.participant_hands, fn hand ->
            hand.participant_id == participant.id && hand.status == :playing
          end)
        else
          nil
        end

      if participant_hand do
        # Active hand - use Multi pattern to fold, sit out, and switch turns
        handle_sit_out_during_hand(table, command, participant_hand)
      else
        # No active hand - just sit out (no turn switching needed)
        %ParticipantSatOut{
          participant_id: participant.id,
          table_id: command.table_id
        }
      end
    end
  end

  def handle(table, %SitInParticipant{} = command) do
    participant = Enum.find(table.participants, &(&1.player_id == command.player_id))

    if participant && participant.is_sitting_out do
      %ParticipantSatIn{
        participant_id: participant.id,
        table_id: command.table_id
      }
    else
      :ok
    end
  end

  def handle(table, %ParticipantFold{} = command) do
    with {:ok, participant} <- find_participant_by_player_id(table, command.player_id) do
      participant_hand =
        Enum.find(table.participant_hands, fn hand -> hand.participant_id == participant.id end)

      %ParticipantFolded{
        id: participant_hand.id,
        participant_id: participant.id,
        table_hand_id: table.hand.id,
        table_id: table.id,
        status: :folded,
        round: table.round.type,
        folded_at: DateTime.utc_now()
      }
    end
  end

  def handle(table, %ParticipantCheck{} = command) do
    with {:ok, participant} <- find_participant_by_player_id(table, command.player_id) do
      participant_hand =
        Enum.find(table.participant_hands, fn hand -> hand.participant_id == participant.id end)

      %ParticipantChecked{
        id: participant_hand.id,
        participant_id: participant.id,
        table_hand_id: table.hand.id,
        table_id: table.id,
        status: :playing,
        round: table.round.type
      }
    end
  end

  def handle(table, %ParticipantCall{} = command) do
    with {:ok, participant} <- find_participant_by_player_id(table, command.player_id) do
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
          participant_id: participant.id,
          table_hand_id: table.id,
          table_id: table.id,
          status: :playing,
          amount: call_amount,
          round: table.round.type
        }
      end
    end
  end

  def handle(table, %ParticipantRaise{} = command) do
    with {:ok, participant} <- find_participant_by_player_id(table, command.player_id) do
      participant_hand =
        Enum.find(table.participant_hands, fn hand -> hand.participant_id == participant.id end)

      raise_amount = command.amount - participant_hand.bet_this_round

      if participant.chips < raise_amount do
        {:error, :insufficient_chips}
      else
        if participant.chips == raise_amount do
          %ParticipantWentAllIn{
            id: participant_hand.id,
            participant_id: participant.id,
            table_hand_id: table.hand.id,
            table_id: table.id,
            status: :playing,
            amount: participant.chips,
            round: table.round.type
          }
        else
          %ParticipantRaised{
            id: participant_hand.id,
            participant_id: participant.id,
            table_hand_id: table.hand.id,
            table_id: table.id,
            status: :playing,
            amount: raise_amount,
            round: table.round.type
          }
        end
      end
    end
  end

  def handle(table, %ParticipantAllIn{} = command) do
    with {:ok, participant} <- find_participant_by_player_id(table, command.player_id) do
      participant_hand =
        Enum.find(table.participant_hands, fn hand -> hand.participant_id == participant.id end)

      %ParticipantWentAllIn{
        id: participant_hand.id,
        participant_id: participant.id,
        table_hand_id: table.hand.id,
        table_id: table.id,
        status: :playing,
        amount: participant.chips,
        round: table.round.type
      }
    end
  end

  defp find_participant_by_player_id(table, player_id) do
    case Enum.find(table.participants, &(&1.player_id == player_id)) do
      nil ->
        {:error,
         %{status: :participant_not_found, message: "You are not a participant at this table"}}

      participant ->
        {:ok, participant}
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

  # Private function following TimeoutParticipant pattern
  defp handle_sit_out_during_hand(
         %{
           hand: %{id: table_hand_id},
           round: %{id: round_id, type: round_type}
         } = table,
         command,
         participant_hand
       ) do
    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn _table ->
      [
        %ParticipantFolded{
          id: participant_hand.id,
          participant_id: participant_hand.participant_id,
          table_hand_id: table_hand_id,
          table_id: command.table_id,
          status: :folded,
          round: round_type,
          folded_at: DateTime.utc_now()
        },
        %ParticipantSatOut{
          participant_id: participant_hand.participant_id,
          table_id: command.table_id
        }
      ]
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      all_acted? = Helpers.all_acted?(table)
      all_folded_except_one? = Helpers.all_folded_except_one_participant?(table)

      cond do
        all_folded_except_one? ->
          [
            %PotsRecalculated{
              table_id: table.id,
              hand_id: table.hand.id,
              pots: Pot.recalculate_pots(table.participant_hands)
            },
            %RoundCompleted{
              id: round_id,
              hand_id: table_hand_id,
              type: round_type,
              table_id: table.id,
              reason: :all_folded
            }
          ]

        all_acted? ->
          [
            %PotsRecalculated{
              table_id: table.id,
              hand_id: table.hand.id,
              pots: Pot.recalculate_pots(table.participant_hands)
            },
            %RoundCompleted{
              id: round_id,
              hand_id: table_hand_id,
              type: round_type,
              table_id: table.id,
              reason: :all_acted
            }
          ]

        true ->
          # Only select next participant if round is not complete
          next_participant = Helpers.find_next_participant_to_act(table)

          if next_participant do
            %ParticipantToActSelected{
              table_id: table.id,
              round_id: round_id,
              participant_id: next_participant.id,
              timeout_seconds: table.settings.timeout_seconds,
              started_at: DateTime.utc_now() |> DateTime.to_iso8601()
            }
          else
            nil
          end
      end
    end)
  end
end
