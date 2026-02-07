defmodule Poker.Tables.Aggregates.Table.Handlers.Actions do
  @moduledoc """
  Handles participant betting actions (raise, call, fold, all_in).
  """

  alias Poker.Tables.Commands.TimeoutParticipant

  alias Poker.Tables.Events.{
    ParticipantToActSelected,
    ParticipantTimedOut,
    ParticipantFolded,
    ParticipantSatOut,
    PotsRecalculated,
    RoundCompleted
  }

  alias Poker.Tables.Aggregates.Table.Helpers
  alias Poker.Tables.Aggregates.Table.Pot
  alias Poker.Tables.Aggregates.Table.Handlers.Participants

  @doc """
  Handles timeout command separately - emits timeout event and auto-folds/sits out.
  """
  def handle(%{hand: nil}, %TimeoutParticipant{}),
    do: {:error, :no_active_hand}

  def handle(
        %{
          round: %{participant_to_act_id: participant_to_act_id, id: round_id, type: _round_type},
          hand: %{id: _table_hand_id}
        } = _table,
        %TimeoutParticipant{participant_id: participant_id, round_id: command_round_id} = _command
      )
      when participant_to_act_id != participant_id or round_id != command_round_id do
    # Stale timeout - participant already acted or round changed
    {:error, :stale_timeout}
  end

  def handle(
        %{
          hand: %{id: table_hand_id},
          round: %{id: round_id, type: round_type}
        } = table,
        %TimeoutParticipant{} = command
      ) do
    participant_hand =
      Enum.find(table.participant_hands, fn hand ->
        hand.participant_id == command.participant_id
      end)

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
          id: participant_hand.id,
          participant_id: command.participant_id,
          table_hand_id: table_hand_id,
          table_id: command.table_id,
          status: :folded,
          round: round_type,
          folded_at: DateTime.utc_now()
        },
        %ParticipantSatOut{
          table_id: command.table_id,
          participant_id: command.participant_id
        }
      ]
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
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
          :ok
      end
    end)
  end

  # Handles participant action commands.
  # Validates turn, processes action, updates pots, and checks for round completion.
  def handle(%{hand: nil}, _command),
    do: {:error, :no_active_hand}

  def handle(
        %{
          round: %{participant_to_act_id: participant_to_act_id},
          participant_hands: participant_hands
        },
        %{participant_id: participant_id}
      )
      when participant_to_act_id != participant_id do
    {:error,
     %{
       status: :not_participants_turn,
       message: "It's not participant id:#{participant_id}'s turn to act"
     }}
  end

  def handle(
        %{hand: %{id: table_hand_id}, round: %{id: round_id, type: round_type}} = table,
        command
      ) do
    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(&Participants.handle(&1, command))
    |> Commanded.Aggregate.Multi.execute(fn table ->
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
          :ok
      end
    end)
  end
end
