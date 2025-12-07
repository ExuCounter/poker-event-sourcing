defmodule Poker.Tables.Aggregates.Table.Apply.Actions do
  @moduledoc """
  Handles action event application.
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Aggregates.Table.Helpers
  alias Poker.Tables.Events.{ParticipantActedInHand, ParticipantToActSelected}

  def apply(%Table{round: round} = table, %ParticipantActedInHand{} = event) do
    updated_round =
      round
      |> update_acted_participant_ids(event)
      |> maybe_update_last_bet_amount(event)

    updated_participants =
      Helpers.update_participant(
        table,
        event.participant_id,
        &%{
          &1
          | chips: &1.chips - event.amount,
            bet_this_round: &1.bet_this_round + event.amount,
            total_bet_this_hand: &1.total_bet_this_hand + event.amount
        }
      )

    updated_participant_hands =
      Helpers.update_participant_hand(
        table,
        event.participant_id,
        fn hand ->
          participant = Helpers.find_participant_by_id(table, event.participant_id)

          %{
            hand
            | status:
                cond do
                  participant.chips == 0 -> :all_in
                  event.action == :all_in -> :all_in
                  event.action == :fold -> :folded
                  true -> :playing
                end
          }
        end
      )

    %Table{
      table
      | round: updated_round,
        participants: updated_participants,
        participant_hands: updated_participant_hands
    }
  end

  def apply(%Table{round: round} = table, %ParticipantToActSelected{} = event) do
    %Table{table | round: %{round | participant_to_act_id: event.participant_id}}
  end

  defp maybe_update_last_bet_amount(round, %ParticipantActedInHand{action: action, amount: amount})
       when action in [:raise, :all_in] do
    %{round | last_bet_amount: amount}
  end

  defp maybe_update_last_bet_amount(round, _event), do: round

  defp update_acted_participant_ids(round, %ParticipantActedInHand{participant_id: participant_id}) do
    %{round | acted_participant_ids: round.acted_participant_ids ++ [participant_id]}
  end
end
