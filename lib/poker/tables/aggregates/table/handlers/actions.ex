defmodule Poker.Tables.Aggregates.Table.Handlers.Actions do
  @moduledoc """
  Handles participant betting actions (raise, call, fold, all_in).
  """

  alias Poker.Tables.Events.{
    ParticipantActedInHand,
    ParticipantToActSelected,
    PotsRecalculated,
    RoundCompleted
  }

  alias Poker.Tables.Aggregates.Table.Helpers
  alias Poker.Tables.Aggregates.Table.Pot
  alias Poker.Tables.Aggregates.Table.Handlers.Hand

  @doc """
  Handles participant action commands.
  Validates turn, processes action, updates pots, and checks for round completion.
  """
  def handle(%{hand: nil}, _command),
    do: {:error, :no_active_hand}

  def handle(
        %{round: %{participant_to_act_id: participant_to_act_id}},
        %{participant_id: participant_id}
      )
      when participant_to_act_id != participant_id,
      do:
        {:error,
         %{
           status: :not_participants_turn,
           message: "It's not participant id:#{participant_id}'s turn to act"
         }}

  def handle(
        %{hand: %{id: table_hand_id}, round: %{id: round_id, type: round_type}} = table,
        command
      ) do
    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(&process_action(&1, command))
    |> Commanded.Aggregate.Multi.execute(fn table ->
      next_participant = Helpers.find_next_participant_to_act(table)

      %ParticipantToActSelected{
        table_id: table.id,
        hand_id: table_hand_id,
        participant_id: next_participant.id
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      %PotsRecalculated{
        table_id: table.id,
        hand_id: table_hand_id,
        pots: Pot.recalculate_pots(table.participant_hands)
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      all_folded_except_one_participant? = Helpers.all_folded_except_one_participant?(table)
      all_acted? = Helpers.all_acted?(table)

      cond do
        all_folded_except_one_participant? ->
          Hand.finish_hand(table, :all_folded)

        all_acted? ->
          %RoundCompleted{
            id: round_id,
            hand_id: table_hand_id,
            type: round_type,
            table_id: table.id
          }

        true ->
          :ok
      end
    end)
  end

  defp process_action(table, %{action: :raise} = command) do
    participant = Helpers.find_participant_to_act(table)

    participant_hand =
      Enum.find(table.participant_hands, fn hand -> hand.participant_id == participant.id end)

    raise_amount = command.amount - participant_hand.bet_this_round

    if participant.chips < raise_amount do
      {:error, :insufficient_chips}
    else
      %ParticipantActedInHand{
        id: command.hand_action_id,
        participant_id: command.participant_id,
        table_hand_id: table.hand.id,
        action: command.action,
        amount: raise_amount,
        round: table.round.type
      }
    end
  end

  defp process_action(table, %{action: :call} = command) do
    participant = Helpers.find_participant_to_act(table)
    last_bet_amount = table.round.last_bet_amount

    participant_hand =
      Enum.find(table.participant_hands, fn hand -> hand.participant_id == participant.id end)

    call_amount =
      [last_bet_amount - participant_hand.bet_this_round, participant.chips]
      |> Enum.filter(&(&1 >= 0))
      |> Enum.min()

    if participant.chips < call_amount do
      {:error, :insufficient_chips}
    else
      %ParticipantActedInHand{
        id: command.hand_action_id,
        participant_id: command.participant_id,
        table_hand_id: table.hand.id,
        action: command.action,
        amount: call_amount,
        round: table.round.type
      }
    end
  end

  defp process_action(table, %{action: :all_in} = command) do
    participant = Helpers.find_participant_to_act(table)

    %ParticipantActedInHand{
      id: command.hand_action_id,
      participant_id: command.participant_id,
      table_hand_id: table.hand.id,
      action: command.action,
      amount: participant.chips,
      round: table.round.type
    }
  end

  defp process_action(table, %{action: :fold} = command) do
    %ParticipantActedInHand{
      id: command.hand_action_id,
      participant_id: command.participant_id,
      table_hand_id: table.hand.id,
      action: command.action,
      amount: 0,
      round: table.round.type
    }
  end

  defp process_action(_table, _command), do: :ok
end
