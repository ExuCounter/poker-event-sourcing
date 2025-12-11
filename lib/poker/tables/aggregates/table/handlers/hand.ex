defmodule Poker.Tables.Aggregates.Table.Handlers.Hand do
  @moduledoc """
  Handles hand lifecycle for poker tables.
  Manages starting hands, dealing cards, posting blinds, and finishing hands.
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
    PotsRecalculated,
    HandFinished,
    TableFinished,
    ParticipantBusted
  }

  alias Poker.Tables.Aggregates.Table.Helpers
  alias Poker.Tables.Aggregates.Table.Position
  alias Poker.Tables.Aggregates.Table.Pot

  @doc """
  Handles hand commands.
  """
  def handle(table, %StartHand{} = command) do
    active_participants = Helpers.filter_active_participants(table.participants)

    if length(active_participants) >= 2 do
      start_hand(table, command.hand_id)
    else
      %TableFinished{
        table_id: table.id,
        reason: :completed
      }
    end
  end

  def handle(%{hand: nil}, %FinishHand{}),
    do: {:error, :no_active_hand}

  def handle(%{hand: %{id: hand_id}}, %FinishHand{hand_id: command_hand_id})
      when hand_id != command_hand_id,
      do: {:error, :hand_id_mismatch}

  def handle(table, %FinishHand{} = command),
    do: finish_hand(table, command.finish_reason)

  def start_hand(table, hand_id) do
    active_participants = Helpers.filter_active_participants(table.participants)

    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn table ->
      shuffled_deck = Poker.Services.Deck.generate_deck() |> Poker.Services.Deck.shuffle_deck()

      %DeckGenerated{
        hand_id: hand_id,
        table_id: table.id,
        cards: shuffled_deck
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
      %HandStarted{
        id: hand_id,
        table_id: table.id
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      %RoundStarted{
        id: Ecto.UUID.generate(),
        hand_id: hand_id,
        type: :pre_flop,
        last_bet_amount: table.settings.big_blind,
        community_cards: []
      }
    end)
    |> Commanded.Aggregate.Multi.reduce(active_participants, fn table, participant ->
      {hole_cards, remaining_deck} = Poker.Services.Deck.pick_cards(table.remaining_deck, 2)

      position = Position.calculate_position(table, participant)

      [
        %ParticipantHandGiven{
          id: Ecto.UUID.generate(),
          table_id: table.id,
          participant_id: participant.id,
          table_hand_id: hand_id,
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
      if Helpers.heads_up?(table) do
        hand = Helpers.find_participant_hand_by_position(table.participant_hands, :dealer)

        %SmallBlindPosted{
          id: Ecto.UUID.generate(),
          table_id: table.id,
          hand_id: hand_id,
          participant_id: hand.participant_id,
          amount: table.settings.small_blind
        }
      else
        hand = Helpers.find_participant_hand_by_position(table.participant_hands, :small_blind)

        %SmallBlindPosted{
          id: Ecto.UUID.generate(),
          table_id: table.id,
          hand_id: hand_id,
          participant_id: hand.participant_id,
          amount: table.settings.small_blind
        }
      end
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      hand = Helpers.find_participant_hand_by_position(table.participant_hands, :big_blind)

      %BigBlindPosted{
        id: Ecto.UUID.generate(),
        table_id: table.id,
        hand_id: hand_id,
        participant_id: hand.participant_id,
        amount: table.settings.big_blind
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      participant_to_act = Helpers.find_participant_to_act(table)

      %ParticipantToActSelected{
        table_id: table.id,
        hand_id: hand_id,
        participant_id: participant_to_act.id
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      %PotsRecalculated{
        table_id: table.id,
        hand_id: hand_id,
        pots: Pot.recalculate_pots(table.participant_hands)
      }
    end)
  end

  def finish_hand(table, :all_folded = reason) do
    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn %{
                                              hand: %{id: hand_id},
                                              pots: pots,
                                              participant_hands: participant_hands,
                                              community_cards: community_cards
                                            } ->
      active_participant_hand =
        Enum.find(participant_hands, fn hand -> hand.status == :playing end)

      payouts =
        Enum.reduce(pots, [], fn pot, acc ->
          acc ++
            [
              %{
                participant_id: active_participant_hand.participant_id,
                amount: pot.amount,
                hand_rank: nil
              }
            ]
        end)

      %HandFinished{
        table_id: table.id,
        hand_id: table.hand.id,
        finish_reason: reason,
        payouts: payouts
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
  end

  def finish_hand(table, :showdown = reason) do
    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn %{
                                              hand: %{id: hand_id},
                                              pots: pots,
                                              participant_hands: participant_hands,
                                              community_cards: community_cards
                                            } ->
      payouts =
        Enum.reduce(pots, [], fn pot, acc ->
          contributing_participant_hands =
            participant_hands
            |> Enum.filter(&(&1.participant_id in pot.contributing_participant_ids))

          winners =
            Poker.Services.HandEvaluator.determine_winners(
              contributing_participant_hands,
              community_cards
            )

          payouts =
            Enum.map(
              winners,
              &%{
                participant_id: &1.participant_id,
                amount: pot.amount,
                hand_rank: &1.hand_rank
              }
            )

          acc ++ payouts
        end)

      %HandFinished{
        table_id: table.id,
        hand_id: table.hand.id,
        finish_reason: reason,
        payouts: payouts
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
  end
end
