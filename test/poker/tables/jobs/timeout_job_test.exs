defmodule Poker.Tables.Jobs.TimeoutJobTest do
  use Poker.DataCase

  alias Poker.Tables.Events.{
    ParticipantTimedOut,
    ParticipantFolded,
    ParticipantSatOut
  }

  use Oban.Testing, repo: Poker.Repo

  describe "timeout job with 500ms timeout" do
    setup ctx do
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
      |> exec(:add_participants, generate_players: 3)
    end

    test "player acts before timeout - should succeed and cancel job", ctx do
      ctx = ctx |> exec(:start_table)

      acting_participant_id = ctx.table.round.participant_to_act_id

      ctx = ctx |> exec(:call_hand)

      assert ctx.table.round.participant_to_act_id != acting_participant_id
      refute ctx.table.round.participant_to_act_id == nil

      updated_participant =
        Enum.find(ctx.table.participants, &(&1.id == acting_participant_id))

      assert updated_participant.is_sitting_out == false
      assert updated_participant.status == :active

      # Job for this participant should be cancelled (no longer scheduled)
      scheduled_jobs = all_enqueued(worker: Poker.Tables.Jobs.TimeoutJob)

      refute Enum.any?(scheduled_jobs, fn job ->
               job.args["participant_id"] == acting_participant_id
             end)
    end

    test "player does not act - timeout fires, auto-fold and sit out", ctx do
      ctx = ctx |> exec(:start_table)

      initial_round_id = ctx.table.round.id
      acting_participant_id = ctx.table.round.participant_to_act_id

      assert %{success: 1} = Oban.drain_queue(queue: :tables, with_scheduled: true)

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
  end
end
