defmodule Poker.Tables.Aggregates.Table.Handlers.Hand do
  @moduledoc """
  Handles hand lifecycle commands for poker tables.

  This module processes the following commands:
  - `StartHand` - Starts a new hand (deals cards, posts blinds)
  - `FinishHand` - Completes a hand (determines winners, distributes pots)

  ## Hand Start Flow
  1. Move dealer button
  2. Generate and shuffle deck
  3. Start pre-flop round
  4. Deal hole cards to each participant
  5. Post small and big blinds
  6. Select first participant to act

  ## Hand Finish Scenarios
  - `:all_folded` - All but one player folded, winner takes pot
  - `:showdown` - Multiple players remain, best hand wins
  """

  alias Poker.Tables.Commands.{StartHand, FinishHand}

  alias Poker.Tables.Events.{
    DeckGenerated,
    DealerButtonMoved,
    HandStarted,
    RoundStarted,
    ParticipantHandGiven,
    DeckUpdated,
    SmallBlindPosted,
    BigBlindPosted,
    ParticipantToActSelected,
    HandFinished,
    TableFinished,
    TablePaused,
    ParticipantBusted,
    ParticipantShowdownCardsRevealed,
    PayoutDistributed
  }

  alias Poker.Tables.Aggregates.Table.Helpers
  alias Poker.Tables.Aggregates.Table.Position

  # =============================================================================
  # START HAND
  # =============================================================================

  @doc "Starts a new hand or pauses/finishes table if not enough players."
  def handle(table, %StartHand{} = command) do
    playing_participants = Helpers.filter_playing_participants(table.participants)

    cond do
      length(playing_participants) < 2 ->
        active_participants = Helpers.filter_active_participants(table.participants)

        if length(active_participants) < 2 do
          %TableFinished{
            table_id: table.id,
            reason: :completed
          }
        else
          %TablePaused{
            table_id: table.id,
            reason: :all_sitting_out
          }
        end

      true ->
        start_hand(table, command.hand_id)
    end
  end

  # =============================================================================
  # FINISH HAND
  # =============================================================================

  def handle(%{hand: nil}, %FinishHand{}),
    do: {:error, :no_active_hand}

  def handle(%{hand: %{id: hand_id}}, %FinishHand{hand_id: command_hand_id})
      when hand_id != command_hand_id do
    {:error, :hand_id_mismatch}
  end

  # Finishes the hand with the given reason (:all_folded or :showdown).
  def handle(table, %FinishHand{} = command),
    do: finish_hand(table, command.finish_reason)

  # =============================================================================
  # PRIVATE - HAND START
  # =============================================================================

  defp start_hand(table, hand_id) do
    # Only deal cards to participants who are active and not sitting out
    playing_participants = Helpers.filter_playing_participants(table.participants)

    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn table ->
      %HandStarted{
        id: hand_id,
        table_id: table.id
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      dealer_button_participant = Helpers.find_dealer_button_participant(table)

      %DealerButtonMoved{
        table_id: table.id,
        hand_id: hand_id,
        participant_id: dealer_button_participant.id
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      shuffled_deck = Poker.Services.Deck.generate_deck() |> Poker.Services.Deck.shuffle_deck()

      %DeckGenerated{
        hand_id: hand_id,
        table_id: table.id,
        cards: shuffled_deck
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      %RoundStarted{
        id: UUIDv7.generate(),
        hand_id: hand_id,
        table_id: table.id,
        type: :pre_flop,
        community_cards: []
      }
    end)
    |> Commanded.Aggregate.Multi.reduce(playing_participants, fn table, participant ->
      {hole_cards, remaining_deck} = Poker.Services.Deck.pick_cards(table.remaining_deck, 2)

      position = Position.calculate_position(table, participant)

      [
        %ParticipantHandGiven{
          id: UUIDv7.generate(),
          table_id: table.id,
          participant_id: participant.id,
          hand_id: hand_id,
          hole_cards: hole_cards,
          position: position,
          status: :playing,
          bet_this_round: 0,
          total_bet_this_hand: 0
        },
        %DeckUpdated{
          hand_id: hand_id,
          table_id: table.id,
          cards: remaining_deck
        }
      ]
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      sb_participant =
        if Helpers.heads_up?(table) do
          Helpers.find_participant_by_position(table, :dealer)
        else
          Helpers.find_participant_by_position(table, :small_blind)
        end

      %SmallBlindPosted{
        id: UUIDv7.generate(),
        table_id: table.id,
        hand_id: hand_id,
        participant_id: sb_participant.id,
        amount: table.settings.small_blind
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      bb_participant = Helpers.find_participant_by_position(table, :big_blind)

      %BigBlindPosted{
        id: UUIDv7.generate(),
        table_id: table.id,
        hand_id: hand_id,
        participant_id: bb_participant.id,
        amount: table.settings.big_blind
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      participant_to_act = Helpers.find_participant_to_act(table)

      %ParticipantToActSelected{
        table_id: table.id,
        round_id: table.round.id,
        participant_id: participant_to_act.id,
        timeout_seconds: table.settings.timeout_seconds,
        started_at: DateTime.utc_now()
      }
    end)
  end

  # =============================================================================
  # PRIVATE - HAND FINISH
  # =============================================================================

  defp finish_hand(table, :all_folded = reason) do
    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn %{
                                              hand: %{id: hand_id},
                                              pots: pots,
                                              participant_hands: participant_hands
                                            } = table ->
      active_participant_hand =
        Enum.find(participant_hands, fn hand -> hand.status != :folded end)

      winner_participant_id =
        if active_participant_hand do
          active_participant_hand.participant_id
        else
          participant_hands
          |> Enum.filter(fn hand -> hand.folded_at != nil end)
          |> Enum.max_by(fn hand -> hand.folded_at end, DateTime)
          |> then(& &1.id)
        end

      total_amount = Enum.reduce(pots, 0, fn pot, acc -> acc + pot.amount end)

      %PayoutDistributed{
        table_id: table.id,
        hand_id: hand_id,
        pot_id: nil,
        participant_id: winner_participant_id,
        amount: total_amount,
        pot_type: :combined,
        hand_rank: nil
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      busted_participants =
        Enum.filter(table.participants, fn participant -> participant.chips == 0 end)

      Enum.map(busted_participants, fn participant ->
        %ParticipantBusted{
          participant_id: participant.id,
          hand_id: table.hand.id,
          table_id: table.id
        }
      end)
    end)
    |> Commanded.Aggregate.Multi.execute(fn %{hand: %{id: hand_id}} ->
      %HandFinished{
        table_id: table.id,
        hand_id: hand_id,
        finish_reason: reason
      }
    end)
  end

  defp finish_hand(table, :showdown = reason) do
    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn %{
                                              hand: %{id: hand_id},
                                              participant_hands: participant_hands
                                            } ->
      # Emit showdown cards revealed events for all active participants
      participant_hands
      |> Enum.filter(&(&1.status != :folded))
      |> Enum.map(fn participant_hand ->
        %ParticipantShowdownCardsRevealed{
          table_id: table.id,
          hand_id: hand_id,
          participant_id: participant_hand.participant_id,
          hole_cards: participant_hand.hole_cards
        }
      end)
    end)
    |> Commanded.Aggregate.Multi.execute(fn %{
                                              hand: %{id: hand_id},
                                              pots: pots,
                                              participant_hands: participant_hands,
                                              community_cards: community_cards
                                            } ->
      Enum.flat_map(pots, fn pot ->
        contributing_participant_hands =
          participant_hands
          |> Enum.filter(&(&1.participant_id in pot.contributing_participant_ids))

        winners =
          Poker.HandEvaluator.determine_winners(
            contributing_participant_hands,
            community_cards
          )

        # Split pot among winners
        winner_count = length(winners)
        split_amount = div(pot.amount, winner_count)
        remainder = rem(pot.amount, winner_count)

        winners
        |> Enum.with_index()
        |> Enum.map(fn {winner, index} ->
          # First winner gets remainder
          amount = if index == 0, do: split_amount + remainder, else: split_amount

          %PayoutDistributed{
            table_id: table.id,
            hand_id: hand_id,
            pot_id: pot.id,
            participant_id: winner.participant_id,
            amount: amount,
            pot_type: pot.type,
            hand_rank: winner.hand_rank
          }
        end)
      end)
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      busted_participants =
        Enum.filter(table.participants, fn participant -> participant.chips == 0 end)

      Enum.map(busted_participants, fn participant ->
        %ParticipantBusted{
          participant_id: participant.id,
          hand_id: table.hand.id,
          table_id: table.id
        }
      end)
    end)
    |> Commanded.Aggregate.Multi.execute(fn %{hand: %{id: hand_id}} ->
      %HandFinished{
        table_id: table.id,
        hand_id: hand_id,
        finish_reason: reason
      }
    end)
  end
end
