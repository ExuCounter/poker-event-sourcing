defmodule Poker.Tournaments.TournamentTableTest do
  use Poker.DataCase
  import Poker.DeckFixtures

  describe "6max table - positions and blinds" do
    setup ctx do
      ctx
      |> exec(:create_tournament,
        settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :six_max}
      )
      |> exec(:fill_tournament)
    end

    test "should give players initial cards and start the hand", ctx do
      assert is_binary(ctx.table.hand.id)
      assert ctx.table.round.type == :pre_flop

      assert length(ctx.table.community_cards) == 0
      assert length(ctx.table.participant_hands) == 6

      Enum.each(ctx.table.participant_hands, fn hand ->
        assert length(hand.hole_cards) == 2

        assert hand.position in [
                 :dealer,
                 :small_blind,
                 :big_blind,
                 :cutoff,
                 :utg,
                 :hijack
               ]

        assert Enum.all?(hand.hole_cards, fn card ->
                 Map.has_key?(card, :rank) and Map.has_key?(card, :suit)
               end)
      end)

      assert ctx.table.status == :live
    end

    test "should have blinds posted on start", ctx do
      positions = Poker.SeedFactorySchema.positions(ctx.table)

      assert positions.small_blind.participant.chips ==
               ctx.table.settings.starting_stack - ctx.table.settings.small_blind

      assert positions.big_blind.participant.chips ==
               ctx.table.settings.starting_stack - ctx.table.settings.big_blind

      assert positions.dealer.participant.chips == ctx.table.settings.starting_stack
      assert positions.cutoff.participant.chips == ctx.table.settings.starting_stack
      assert positions.hijack.participant.chips == ctx.table.settings.starting_stack
      assert positions.utg.participant.chips == ctx.table.settings.starting_stack
    end
  end

  describe "heads up - round progression" do
    setup ctx do
      ctx
      |> exec(:create_tournament,
        settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max}
      )
      |> exec(:fill_tournament)
    end

    test "should calculate pot correctly after first round", ctx do
      ctx = ctx |> exec(:advance_round)

      [pot1] = ctx.table.pots

      assert pot1.amount == ctx.table.settings.big_blind * 2
      assert pot1.bet_amount == ctx.table.settings.big_blind
      assert length(pot1.contributing_participant_ids) == 2
    end

    test "should deal flop after betting round", ctx do
      ctx =
        ctx
        |> exec(:call_hand, position: :dealer)
        |> exec(:call_hand, position: :big_blind)

      assert ctx.table.round.type == :flop
      assert length(ctx.table.community_cards) == 3
    end

    test "should deal turn after flop round", ctx do
      ctx =
        ctx
        |> exec(:advance_round)
        |> exec(:advance_round)

      assert ctx.table.round.type == :turn
      assert length(ctx.table.community_cards) == 4
    end

    test "should deal river after turn round", ctx do
      ctx =
        ctx
        |> exec(:advance_round)
        |> exec(:advance_round)
        |> exec(:advance_round)

      assert ctx.table.round.type == :river
      assert length(ctx.table.community_cards) == 5
    end

    test "raise re-reraise re-reraise call should keep the same round", ctx do
      ctx =
        ctx
        |> exec(:raise_hand, position: :dealer, amount: 60)
        |> exec(:raise_hand, position: :big_blind, amount: 100)
        |> exec(:raise_hand, position: :dealer, amount: 140)

      assert ctx.table.round.type == :pre_flop

      ctx = ctx |> exec(:call_hand, position: :big_blind)

      assert ctx.table.round.type == :flop
    end

    test "fold should finish hand and start a new one", ctx do
      _ctx = ctx |> exec(:fold_hand, position: :dealer)

      assert_receive_event(
        Poker.App,
        Poker.Tables.Events.PayoutDistributed,
        fn event ->
          assert event.amount > 0
          assert event.pot_type == :combined
          assert event.hand_rank == nil
        end
      )

      assert_receive_event(
        Poker.App,
        Poker.Tables.Events.HandFinished,
        fn event ->
          assert event.finish_reason == :all_folded
          refute Map.has_key?(event, :payouts)
        end
      )

      assert_receive_event(
        Poker.App,
        Poker.Tables.Events.HandStarted,
        fn _event -> :ok end
      )
    end

    test "new hand should have no old data", ctx do
      previous_hand_id = ctx.table.hand.id

      ctx = ctx |> exec(:fold_hand, position: :dealer)

      assert ctx.table.hand.id != previous_hand_id
      assert ctx.table.community_cards == []
      assert ctx.table.round.type == :pre_flop
    end
  end

  describe "heads up - showdown and bust" do
    setup ctx do
      ctx
      |> exec(:create_tournament,
        settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max}
      )
    end

    test "all-in should start runout and finish the game", ctx do
      arrange_deck(%{
        dealer: [%{rank: :A, suit: :spades}, %{rank: :K, suit: :spades}],
        big_blind: [%{rank: 2, suit: :hearts}, %{rank: 7, suit: :clubs}],
        community: [
          %{rank: :Q, suit: :spades},
          %{rank: :J, suit: :spades},
          %{rank: :T, suit: :spades},
          %{rank: 2, suit: :diamonds},
          %{rank: 3, suit: :diamonds}
        ]
      })

      ctx = ctx |> exec(:fill_tournament)
      ctx = ctx |> exec(:start_runout)

      assert ctx.table.status == :finished
    end

    test "bust participant", ctx do
      arrange_deck(%{
        dealer: [%{rank: :A, suit: :spades}, %{rank: :K, suit: :spades}],
        big_blind: [%{rank: 2, suit: :hearts}, %{rank: 7, suit: :clubs}],
        community: [
          %{rank: :Q, suit: :spades},
          %{rank: :J, suit: :spades},
          %{rank: :T, suit: :spades},
          %{rank: 2, suit: :diamonds},
          %{rank: 3, suit: :diamonds}
        ]
      })

      ctx = ctx |> exec(:fill_tournament)

      positions = Poker.SeedFactorySchema.positions(ctx.table)
      winner_participant_id = positions.dealer.participant.id
      loser_participant_id = positions.big_blind.participant.id

      ctx = ctx |> exec(:start_runout)

      winner_participant =
        Enum.find(ctx.table.participants, &(&1.id == winner_participant_id))

      loser_participant =
        Enum.find(ctx.table.participants, &(&1.id == loser_participant_id))

      assert winner_participant.chips ==
               winner_participant.initial_chips + loser_participant.initial_chips

      assert winner_participant.status == :active

      assert loser_participant.chips == 0
      assert loser_participant.status == :busted

      assert ctx.table.status == :finished
    end

    test "finish hand with straight flush on showdown", ctx do
      arrange_deck(%{
        dealer: [%{rank: :A, suit: :spades}, %{rank: 2, suit: :hearts}],
        big_blind: [%{rank: 9, suit: :spades}, %{rank: 2, suit: :clubs}],
        community: [
          %{rank: :K, suit: :spades},
          %{rank: :Q, suit: :spades},
          %{rank: :J, suit: :spades},
          %{rank: :T, suit: :spades},
          %{rank: :T, suit: :hearts}
        ]
      })

      ctx = ctx |> exec(:fill_tournament)

      positions = Poker.SeedFactorySchema.positions(ctx.table)
      expected_winner_participant = positions.dealer.participant

      assert [
               %{rank: :A, suit: :spades},
               %{rank: 2, suit: :hearts}
             ] = positions.dealer.hand.hole_cards

      ctx =
        ctx
        |> exec(:advance_round)
        |> exec(:advance_round)
        |> exec(:advance_round)
        |> exec(:advance_round)

      assert_receive_event(
        Poker.App,
        Poker.Tables.Events.PayoutDistributed,
        fn event ->
          assert event.participant_id == expected_winner_participant.id
          assert event.amount == ctx.table.settings.big_blind * 2
          assert event.pot_type == :main
          assert event.hand_rank == {:straight_flush, :A}
        end
      )

      assert_receive_event(
        Poker.App,
        Poker.Tables.Events.HandFinished,
        fn event ->
          assert event.finish_reason == :showdown
          refute Map.has_key?(event, :payouts)
        end
      )
    end
  end
end
