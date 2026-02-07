defmodule Poker.Tables.Jobs.TimeoutJobTest do
  use Poker.DataCase
  import Poker.DeckFixtures

  alias Poker.Tables.Events.{
    ParticipantTimedOut,
    ParticipantFolded,
    ParticipantSatOut,
    ParticipantToActSelected
  }

  use Oban.Testing, repo: Poker.Repo

  describe "timeout job with 500ms timeout" do
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
          timeout_seconds: 1
        }
      )
      |> exec(:add_participants, players: players)
    end

    test "player acts before timeout - should succeed and cancel job", ctx do
      ctx = ctx |> exec(:start_table)

      initial_round_id = ctx.table.round.id
      acting_participant_id = ctx.table.round.participant_to_act_id

      acting_participant =
        Enum.find(ctx.table.participants, &(&1.id == acting_participant_id))

      # Player calls before timeout
      ctx = ctx |> exec(:call_hand)

      # Verify that game continues normally
      assert ctx.table.round.participant_to_act_id != acting_participant_id
      refute ctx.table.round.participant_to_act_id == nil

      updated_participant =
        Enum.find(ctx.table.participants, &(&1.id == acting_participant_id))

      assert updated_participant.is_sitting_out == false
      assert updated_participant.status == :active

      # Try to drain the queue - cancelled jobs should result in 0 success
      # or they fail due to stale state (wrong turn)
      result = Oban.drain_queue(queue: :tables)

      # Verify no successful timeout occurred (job was cancelled or failed)
      assert result.success == 0 or result.failure > 0

      # Verify participant is still active after attempted job execution
      table = Poker.SeedFactorySchema.aggregate_state(:table, ctx.table.id)
      updated_participant = Enum.find(table.participants, &(&1.id == acting_participant_id))
      assert updated_participant.is_sitting_out == false
      assert updated_participant.status == :active
    end

    test "player does not act - timeout fires, auto-fold and sit out", ctx do
      ctx = ctx |> exec(:start_table)

      initial_round_id = ctx.table.round.id
      acting_participant_id = ctx.table.round.participant_to_act_id

      acting_participant =
        Enum.find(ctx.table.participants, &(&1.id == acting_participant_id))

      Process.sleep(100)

      assert %{success: 1, failure: 0} =
               Oban.drain_queue(queue: :tables)

      assert_receive_event(
        Poker.App,
        ParticipantTimedOut,
        fn event ->
          assert event.table_id == ctx.table.id
          assert event.participant_id == acting_participant_id
          assert event.round_id == initial_round_id
        end
      )

      assert_receive_event(
        Poker.App,
        ParticipantFolded,
        fn event ->
          assert event.table_id == ctx.table.id
          assert event.participant_id == acting_participant_id
        end
      )

      assert_receive_event(
        Poker.App,
        ParticipantSatOut,
        fn event ->
          assert event.table_id == ctx.table.id
          assert event.participant_id == acting_participant_id
        end
      )

      table = Poker.SeedFactorySchema.aggregate_state(:table, ctx.table.id)

      timed_out_participant =
        Enum.find(table.participants, &(&1.id == acting_participant_id))

      assert timed_out_participant.is_sitting_out == true

      assert table.round.participant_to_act_id != acting_participant_id
      refute table.round.participant_to_act_id == nil

      participant_hand =
        Enum.find(table.participant_hands, &(&1.participant_id == acting_participant_id))

      assert participant_hand.status == :folded
    end

    test "multiple timeouts - only current turn times out", ctx do
      ctx = ctx |> exec(:start_table)

      first_acting_participant_id = ctx.table.round.participant_to_act_id

      ctx = ctx |> exec(:call_hand)

      second_acting_participant_id = ctx.table.round.participant_to_act_id
      assert second_acting_participant_id != first_acting_participant_id

      assert %{success: 1, failure: 0} =
               Oban.drain_queue(queue: :tables)

      # Verify second player timed out
      assert_receive_event(
        Poker.App,
        ParticipantTimedOut,
        fn event ->
          assert event.participant_id == second_acting_participant_id
        end
      )

      table = Poker.SeedFactorySchema.aggregate_state(:table, ctx.table.id)

      # Verify first player is NOT sitting out (acted in time)
      first_participant =
        Enum.find(table.participants, &(&1.id == first_acting_participant_id))

      assert first_participant.is_sitting_out == false

      # Verify second player IS sitting out (timed out)
      second_participant =
        Enum.find(table.participants, &(&1.id == second_acting_participant_id))

      assert second_participant.is_sitting_out == true
    end

    test "sitting out player is skipped in turn selection", ctx do
      ctx = ctx |> exec(:start_table)

      first_acting_participant_id = ctx.table.round.participant_to_act_id

      # Manually execute timeout for first player
      assert %{success: 1, failure: 0} =
               Oban.drain_queue(queue: :tables)

      table = Poker.SeedFactorySchema.aggregate_state(:table, ctx.table.id)

      # Verify first player is sitting out
      first_participant =
        Enum.find(table.participants, &(&1.id == first_acting_participant_id))

      assert first_participant.is_sitting_out == true

      # Verify second player got the turn (sitting out player was skipped)
      second_participant_id = table.round.participant_to_act_id
      assert second_participant_id != first_acting_participant_id

      second_participant = Enum.find(table.participants, &(&1.id == second_participant_id))
      assert second_participant.is_sitting_out == false

      # Second player acts
      :ok =
        Poker.Tables.call_hand(
          table.id,
          second_participant.player_id
        )

      Poker.TestSupport.ProcessManagerAwaiter.wait_to_settle()

      # Verify round advanced (all active players have acted)
      table = Poker.SeedFactorySchema.aggregate_state(:table, ctx.table.id)
      assert table.round.type == :flop
    end
  end
end
