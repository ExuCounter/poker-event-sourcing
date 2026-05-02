defmodule Poker.Events.BroadcastableTest do
  use ExUnit.Case, async: true

  alias Poker.Events.Broadcastable

  describe "for_broadcast/1" do
    test "sensitive events return :skip" do
      event = %Poker.Tables.Events.DeckGenerated{hand_id: "h1", table_id: "t1", cards: ["As", "Kh"]}
      assert :skip = Broadcastable.for_broadcast(event)
    end

    test "ParticipantHandGiven strips hole_cards and includes timing" do
      event = %Poker.Tables.Events.ParticipantHandGiven{
        id: "p1",
        table_id: "t1",
        participant_id: "part1",
        hand_id: "h1",
        hole_cards: [{:ace, :spades}, {:king, :hearts}],
        position: :dealer,
        status: :active,
        bet_this_round: 0,
        total_bet_this_hand: 0
      }

      assert {:broadcast, data, timing} = Broadcastable.for_broadcast(event)
      refute Map.has_key?(data, :hole_cards)
      assert data.participant_id == "part1"
      assert timing.duration > 0
    end

    test "HandFinished has different timing for all_folded" do
      all_folded = %Poker.Tables.Events.HandFinished{table_id: "t1", hand_id: "h1", finish_reason: :all_folded}
      showdown = %Poker.Tables.Events.HandFinished{table_id: "t1", hand_id: "h1", finish_reason: :showdown}

      assert {:broadcast, _, %{duration: folded_duration}} = Broadcastable.for_broadcast(all_folded)
      assert {:broadcast, _, %{duration: showdown_duration}} = Broadcastable.for_broadcast(showdown)
      assert folded_duration < showdown_duration
    end

    test "all skipped events return :skip" do
      skipped_events = [
        %Poker.Tables.Events.DeckGenerated{hand_id: "h1", table_id: "t1", cards: []},
        %Poker.Tables.Events.DeckUpdated{hand_id: "h1", table_id: "t1", cards: []},
        %Poker.Tables.Events.RoundCompleted{id: "r1", hand_id: "h1", table_id: "t1", type: :flop, reason: :completed},
        %Poker.Tables.Events.TableCreated{id: "t1", creator_id: "c1", status: :waiting, small_blind: 10, big_blind: 20, starting_stack: 1000, timeout_seconds: 30, table_type: :six_max, game_mode: :cash_game, source_id: nil},
        %Poker.Tables.Events.TableStarted{id: "t1", status: :live},
        %Poker.Tables.Events.TableFinished{table_id: "t1", reason: :completed},
        %Poker.Tables.Events.TablePaused{table_id: "t1", reason: :blind_level},
        %Poker.Tables.Events.TableResumed{table_id: "t1"},
        %Poker.Tables.Events.ParticipantJoined{id: "p1", player_id: "pl1", table_id: "t1", chips: 1000, initial_chips: 1000, status: :active, is_sitting_out: false, nickname: "test", seat_number: 1},
        %Poker.Tables.Events.ParticipantLeft{table_id: "t1", participant_id: "p1", player_id: "pl1", chips: 1000},
        %Poker.Tables.Events.ParticipantBusted{table_id: "t1", hand_id: "h1", participant_id: "p1", player_id: "pl1"},
        %Poker.Tables.Events.TableBlindsUpdated{table_id: "t1", small_blind: 20, big_blind: 40},
        %Poker.Tables.Events.ParticipantBoughtIn{participant_id: "p1", player_id: "pl1", table_id: "t1", amount: 1000},
        %Poker.Tables.Events.ParticipantBuyInApplied{participant_id: "p1", table_id: "t1", amount: 1000}
      ]

      for event <- skipped_events do
        assert :skip = Broadcastable.for_broadcast(event),
               "Expected :skip for #{inspect(event.__struct__)}"
      end
    end

    test "events with timing return {:broadcast, data, timing}" do
      events_with_timing = [
        %Poker.Tables.Events.HandStarted{id: "h1", table_id: "t1"},
        %Poker.Tables.Events.HandFinished{table_id: "t1", hand_id: "h1", finish_reason: :showdown},
        %Poker.Tables.Events.SmallBlindPosted{id: "sb1", table_id: "t1", hand_id: "h1", participant_id: "p1", amount: 10},
        %Poker.Tables.Events.BigBlindPosted{id: "bb1", table_id: "t1", hand_id: "h1", participant_id: "p2", amount: 20},
        %Poker.Tables.Events.ParticipantFolded{participant_id: "p1", hand_id: "h1", table_id: "t1", status: :folded, round: :preflop, folded_at: :preflop},
        %Poker.Tables.Events.ParticipantCalled{participant_id: "p1", hand_id: "h1", table_id: "t1", status: :called, amount: 20, round: :preflop},
        %Poker.Tables.Events.ParticipantChecked{participant_id: "p1", hand_id: "h1", table_id: "t1", status: :checked, round: :flop},
        %Poker.Tables.Events.ParticipantRaised{participant_id: "p1", hand_id: "h1", table_id: "t1", status: :raised, amount: 40, round: :preflop},
        %Poker.Tables.Events.ParticipantWentAllIn{participant_id: "p1", hand_id: "h1", table_id: "t1", status: :all_in, amount: 1000, round: :preflop},
        %Poker.Tables.Events.RoundStarted{id: "r1", hand_id: "h1", table_id: "t1", type: :flop, community_cards: []},
        %Poker.Tables.Events.PotsRecalculated{id: "pot1", table_id: "t1", hand_id: "h1", pots: []},
        %Poker.Tables.Events.PayoutDistributed{table_id: "t1", hand_id: "h1", pot_id: "pot1", participant_id: "p1", amount: 100, pot_type: :main, hand_rank: nil},
        %Poker.Tables.Events.ParticipantShowdownCardsRevealed{table_id: "t1", hand_id: "h1", participant_id: "p1", hole_cards: []},
        %Poker.Tables.Events.ParticipantHandGiven{id: "p1", table_id: "t1", participant_id: "part1", hand_id: "h1", hole_cards: [], position: :dealer, status: :active, bet_this_round: 0, total_bet_this_hand: 0}
      ]

      for event <- events_with_timing do
        assert {:broadcast, data, timing} = Broadcastable.for_broadcast(event),
               "Expected {:broadcast, _, timing} for #{inspect(event.__struct__)}"

        assert is_map(data)
        assert is_map(timing)
        assert timing.duration > 0
      end
    end

    test "events without timing return {:broadcast, data}" do
      events_without_timing = [
        %Poker.Tables.Events.ParticipantTimedOut{id: "to1", table_id: "t1", participant_id: "p1", round_id: "r1"},
        %Poker.Tables.Events.ParticipantSatOut{participant_id: "p1", table_id: "t1"},
        %Poker.Tables.Events.ParticipantSatIn{participant_id: "p1", table_id: "t1"},
        %Poker.Tables.Events.ParticipantToActSelected{table_id: "t1", round_id: "r1", participant_id: "p1", timeout_seconds: 30, started_at: nil},
        %Poker.Tables.Events.DealerButtonMoved{table_id: "t1", hand_id: "h1", participant_id: "p1"}
      ]

      for event <- events_without_timing do
        assert {:broadcast, data} = Broadcastable.for_broadcast(event),
               "Expected {:broadcast, _} (no timing) for #{inspect(event.__struct__)}"

        assert is_map(data)
      end
    end
  end
end
