defmodule Poker.Tables.Aggregates.Table.Handlers.Actions do
  @moduledoc """
  Handles participant betting actions (raise, call, fold, all_in).
  """

  alias Poker.Tables.Events.{
    ParticipantToActSelected,
    PotsRecalculated,
    RoundCompleted
  }

  alias Poker.Tables.Aggregates.Table.Helpers
  alias Poker.Tables.Aggregates.Table.Pot
  alias Poker.Tables.Aggregates.Table.Handlers.Participants

  @doc """
  Handles participant action commands.
  Validates turn, processes action, updates pots, and checks for round completion.
  """
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

      dbg(next_participant)

      %ParticipantToActSelected{
        table_id: table.id,
        round_id: round_id,
        participant_id: next_participant.id
      }
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
