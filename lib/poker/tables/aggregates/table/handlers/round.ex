defmodule Poker.Tables.Aggregates.Table.Handlers.Round do
  @moduledoc """
  Handles round lifecycle and management for poker hands.
  Manages transitions between pre-flop, flop, turn, and river.
  """

  alias Poker.Tables.Commands.StartRound
  alias Poker.Tables.Events.{RoundStarted, RoundCompleted, DeckUpdated, ParticipantToActSelected}
  alias Poker.Tables.Aggregates.Table.Helpers

  @doc """
  Handles round commands.
  """
  def handle(%{hand: %{id: hand_id}}, %StartRound{hand_id: command_hand_id})
      when hand_id != command_hand_id,
      do: {:error, :hand_id_mismatch}

  def handle(table, %StartRound{} = command) do
    if Helpers.runout?(table) do
      table
      |> Commanded.Aggregate.Multi.new()
      |> Commanded.Aggregate.Multi.execute(&start_round(&1, command))
      |> Commanded.Aggregate.Multi.execute(fn table ->
        %RoundCompleted{
          id: table.round.id,
          hand_id: table.hand.id,
          type: table.round.type,
          table_id: table.id
        }
      end)
    else
      start_round(table, command)
    end
  end

  defp start_round(table, command) do
    participant_to_act = Helpers.find_participant_to_act(table)

    community_cards_count =
      case command.round do
        :flop -> 3
        :turn -> 1
        :river -> 1
      end

    {community_cards, remaining_deck} =
      Poker.Services.Deck.pick_cards(table.remaining_deck, community_cards_count)

    [
      %RoundStarted{
        id: command.round_id,
        hand_id: command.hand_id,
        type: command.round,
        last_bet_amount: 0,
        community_cards: community_cards
      },
      %DeckUpdated{
        hand_id: command.hand_id,
        table_id: table.id,
        cards: remaining_deck
      },
      %ParticipantToActSelected{
        table_id: table.id,
        hand_id: command.hand_id,
        participant_id: participant_to_act.id
      }
    ]
  end
end
