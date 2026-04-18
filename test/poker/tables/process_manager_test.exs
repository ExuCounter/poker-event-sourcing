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
      players =
        for _ <- 1..3 do
          %{player: player} = produce(ctx, :player)
          player
        end

      ctx
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, players: players)
    end

    test "starts hand when table starts", ctx do
      ctx = ctx |> exec(:start_table)

      assert_receive_event(Poker.App, TableStarted, fn event ->
        assert event.id == ctx.table.id
      end)

      assert_receive_event(Poker.App, HandStarted, fn event ->
        assert event.table_id == ctx.table.id
      end)

      table = Poker.SeedFactorySchema.aggregate_state(:table, ctx.table.id)
      assert table.hand != nil
      assert table.round != nil
      assert table.round.type == :pre_flop
    end

    test "starts new hand when hand finishes", ctx do
      ctx =
        ctx
        |> exec(:start_table)
        |> exec(:fold_hand)
        |> exec(:fold_hand)

      # Wait for process manager to process events
      Poker.TestSupport.ProcessManagerAwaiter.wait_to_settle()

      assert_receive_event(Poker.App, HandFinished, fn event ->
        assert event.table_id == ctx.table.id
        assert event.finish_reason == :all_folded
      end)

      # New hand should start
      table = Poker.SeedFactorySchema.aggregate_state(:table, ctx.table.id)
      assert table.hand != nil
      assert table.round.type == :pre_flop
    end
  end

  describe "process manager - round progression" do
    setup ctx do
      players =
        for _ <- 1..2 do
          %{player: player} = produce(ctx, :player)
          player
        end

      ctx
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, players: players)
    end

    test "advances to flop after pre-flop all acted", ctx do
      ctx =
        ctx
        |> exec(:start_table)
        |> exec(:call_hand)
        |> exec(:check_hand)

      Poker.TestSupport.ProcessManagerAwaiter.wait_to_settle()

      # Verify round advanced to flop
      table = Poker.SeedFactorySchema.aggregate_state(:table, ctx.table.id)
      assert table.round.type == :flop
      assert length(table.community_cards) == 3
    end

    test "finishes hand at showdown after river", ctx do
      ctx =
        ctx
        |> exec(:start_table)
        # Pre-flop
        |> exec(:call_hand)
        |> exec(:check_hand)
        # Flop
        |> exec(:check_hand)
        |> exec(:check_hand)
        # Turn
        |> exec(:check_hand)
        |> exec(:check_hand)
        # River
        |> exec(:check_hand)
        |> exec(:check_hand)

      Poker.TestSupport.ProcessManagerAwaiter.wait_to_settle()

      # Verify hand finished at showdown
      assert_receive_event(Poker.App, HandFinished, fn event ->
        assert event.table_id == ctx.table.id
        assert event.finish_reason == :showdown
      end)
    end

    test "finishes hand early when all fold except one", ctx do
      ctx =
        ctx
        |> exec(:start_table)
        |> exec(:fold_hand)

      Poker.TestSupport.ProcessManagerAwaiter.wait_to_settle()

      # Verify hand finished early when all fold except one
      assert_receive_event(Poker.App, HandFinished, fn event ->
        assert event.table_id == ctx.table.id
        assert event.finish_reason == :all_folded
      end)
    end
  end

  describe "process manager - table pause/resume" do
    setup ctx do
      players =
        for _ <- 1..2 do
          %{player: player} = produce(ctx, :player)
          player
        end

      ctx
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, players: players)
    end

    test "pauses table when not enough playing participants", ctx do
      ctx =
        ctx
        |> exec(:start_table)
        |> exec(:sit_out)
        |> exec(:fold_hand)

      Poker.TestSupport.ProcessManagerAwaiter.wait_to_settle()

      assert_receive_event(Poker.App, TablePaused, fn event ->
        assert event.table_id == ctx.table.id
      end)

      table = Poker.SeedFactorySchema.aggregate_state(:table, ctx.table.id)
      assert table.status == :paused
    end

    test "resumes table when participant sits back in", ctx do
      ctx =
        ctx
        |> exec(:start_table)
        |> exec(:sit_out)
        |> exec(:fold_hand)

      Poker.TestSupport.ProcessManagerAwaiter.wait_to_settle()

      # Table should be paused
      table = Poker.SeedFactorySchema.aggregate_state(:table, ctx.table.id)
      assert table.status == :paused

      # Sit back in
      ctx = ctx |> exec(:sit_in)

      Poker.TestSupport.ProcessManagerAwaiter.wait_to_settle()

      assert_receive_event(Poker.App, TableResumed, fn event ->
        assert event.table_id == ctx.table.id
      end)

      table = Poker.SeedFactorySchema.aggregate_state(:table, ctx.table.id)
      assert table.status == :live
    end
  end

  describe "process manager - sitting out auto-fold" do
    setup ctx do
      players =
        for _ <- 1..3 do
          %{player: player} = produce(ctx, :player)
          player
        end

      ctx
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, players: players)
    end

    test "auto-folds for sitting out player when their turn comes", ctx do
      ctx = ctx |> exec(:start_table)

      # Get the participant who acts after current player
      current_acting_id = ctx.table.round.participant_to_act_id

      # First player sits out while it's their turn (causes fold + sit out)
      ctx = ctx |> exec(:sit_out)

      Poker.TestSupport.ProcessManagerAwaiter.wait_to_settle()

      # Verify they folded
      assert_receive_event(Poker.App, ParticipantFolded, fn event ->
        assert event.participant_id == current_acting_id
      end)

      assert_receive_event(Poker.App, ParticipantSatOut, fn event ->
        assert event.participant_id == current_acting_id
      end)

      # Turn should move to next player
      table = Poker.SeedFactorySchema.aggregate_state(:table, ctx.table.id)
      assert table.round.participant_to_act_id != current_acting_id
    end
  end
end
