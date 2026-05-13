defmodule Poker.Tables.ProcessManagerTest do
  use Poker.DataCase

  alias Poker.Tables.Events.{
    TableStarted,
    HandStarted,
    HandFinished,
    TablePaused,
    TableResumed,
    ParticipantSatOut,
    ParticipantFolded
  }

  describe "process manager - hand lifecycle" do
    setup ctx do
      ctx
      |> exec(:create_tournament,
        settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :three_max}
      )
      |> exec(:fill_tournament)
    end

    test "starts hand when table starts", ctx do
      assert_receive_event(Poker.App, TableStarted, fn event ->
        assert event.id == ctx.table.id
      end)

      assert_receive_event(Poker.App, HandStarted, fn event ->
        assert event.table_id == ctx.table.id
      end)

      assert is_binary(ctx.table.hand.id)
      assert ctx.table.round != nil
      assert ctx.table.round.type == :pre_flop
    end

    test "starts new hand when hand finishes", ctx do
      ctx =
        ctx
        |> exec(:fold_hand, position: :dealer)
        |> exec(:fold_hand, position: :small_blind)

      assert_receive_event(Poker.App, HandFinished, fn event ->
        assert event.table_id == ctx.table.id
        assert event.finish_reason == :all_folded
      end)

      # New hand should start
      assert is_binary(ctx.table.hand.id)
      assert ctx.table.round.type == :pre_flop
    end
  end

  describe "process manager - round progression" do
    setup ctx do
      ctx
      |> exec(:create_tournament,
        settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max}
      )
      |> exec(:fill_tournament)
    end

    test "advances to flop after pre-flop all acted", ctx do
      ctx =
        ctx
        |> exec(:call_hand, position: :dealer)
        |> exec(:call_hand, position: :big_blind)

      assert ctx.table.round.type == :flop
      assert length(ctx.table.community_cards) == 3
    end

    test "finishes hand at showdown after river", ctx do
      ctx =
        ctx
        |> exec(:call_hand, position: :dealer)
        |> exec(:check_hand, position: :big_blind)
        |> exec(:check_hand, position: :big_blind)
        |> exec(:check_hand, position: :dealer)
        |> exec(:check_hand, position: :big_blind)
        |> exec(:check_hand, position: :dealer)
        |> exec(:check_hand, position: :big_blind)
        |> exec(:check_hand, position: :dealer)

      assert_receive_event(Poker.App, HandFinished, fn event ->
        assert event.table_id == ctx.table.id
        assert event.finish_reason == :showdown
      end)
    end

    test "finishes hand early when all fold except one", ctx do
      _ctx = ctx |> exec(:fold_hand, position: :dealer)

      assert_receive_event(Poker.App, HandFinished, fn event ->
        assert event.table_id == ctx.table.id
        assert event.finish_reason == :all_folded
      end)
    end
  end

  describe "process manager - sitting out auto-fold" do
    setup ctx do
      ctx
      |> exec(:create_tournament,
        settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :three_max}
      )
      |> exec(:fill_tournament)
    end

    test "auto-folds for sitting out player when their turn comes", ctx do
      current_acting_id = ctx.table.round.participant_to_act_id

      ctx = ctx |> exec(:sit_out, position: :dealer)

      assert_receive_event(Poker.App, ParticipantFolded, fn event ->
        assert event.participant_id == current_acting_id
      end)

      assert_receive_event(Poker.App, ParticipantSatOut, fn event ->
        assert event.participant_id == current_acting_id
      end)

      assert ctx.table.round.participant_to_act_id != current_acting_id
    end
  end
end
