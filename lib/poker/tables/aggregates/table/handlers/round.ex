defmodule Poker.Tables.Aggregates.Table.Handlers.Round do
  @moduledoc """
  Handles betting round commands for poker hands.

  This module processes the `StartRound` command to transition between:
  - Pre-flop → Flop (3 community cards)
  - Flop → Turn (1 community card)
  - Turn → River (1 community card)

  ## Round Start Flow
  1. Deal community cards from deck
  2. Reset bets for the new round
  3. Select first participant to act (left of dealer)

  ## Special Cases
  - **Runout**: When only one player can act (others all-in), rounds
    complete immediately without betting
  - **Hand ID mismatch**: Rejects stale commands from previous hands
  """

  alias Poker.Tables.Commands.StartRound

  alias Poker.Tables.Events.{RoundStarted, RoundCompleted, DeckUpdated, ParticipantToActSelected}
  alias Poker.Tables.Aggregates.Table.Helpers

  # =============================================================================
  # START ROUND
  # =============================================================================

  def handle(%{hand: %{id: hand_id}}, %StartRound{hand_id: command_hand_id} = _command)
      when hand_id != command_hand_id do
    {:error, :hand_id_mismatch}
  end

  # Handles case when no participant can act (completes round immediately).
  def handle(
        %{participant_to_act_id: nil} = table,
        %StartRound{hand_id: _command_hand_id} = _command
      ) do
    %RoundCompleted{
      id: table.round.id,
      hand_id: table.hand.id,
      type: table.round.type,
      table_id: table.id,
      reason: :all_acted
    }
  end

  # Starts a new betting round, handling runout scenarios.
  def handle(table, %StartRound{} = command) do
    if Helpers.runout?(table) do
      table
      |> Commanded.Aggregate.Multi.new()
      |> Commanded.Aggregate.Multi.execute(&Helpers.maybe_reveal_cards/1)
      |> Commanded.Aggregate.Multi.execute(&start_round(&1, command))
      |> Commanded.Aggregate.Multi.execute(fn table ->
        %RoundCompleted{
          id: table.round.id,
          hand_id: table.hand.id,
          type: table.round.type,
          table_id: table.id,
          reason: :all_acted
        }
      end)
    else
      start_round(table, command)
    end
  end

  defp start_round(table, command) do
    participant_to_act = Helpers.find_first_postflop_actor(table)

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
        table_id: table.id,
        type: command.round,
        community_cards: community_cards
      },
      %DeckUpdated{
        hand_id: command.hand_id,
        table_id: table.id,
        cards: remaining_deck
      },
      %ParticipantToActSelected{
        table_id: table.id,
        round_id: command.round_id,
        participant_id: participant_to_act.id,
        timeout_seconds: table.settings.timeout_seconds,
        started_at: DateTime.utc_now()
      }
    ]
  end
end
