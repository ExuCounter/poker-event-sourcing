defmodule Poker.Tables.Jobs.TimeoutJobTest do
  use Poker.DataCase

  alias Poker.Tables.Events.{
    ParticipantTimedOut,
    ParticipantFolded,
    ParticipantSatOut
  }

  use Oban.Testing, repo: Poker.Repo

  describe "timeout job" do
    setup ctx do
      ctx
      |> exec(:create_tournament,
        settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :three_max}
      )
      |> exec(:fill_tournament)
    end

    test "player acts before timeout - should succeed and cancel job", ctx do
      acting_participant_id = ctx.table.round.participant_to_act_id

      ctx = ctx |> exec(:call_hand, position: :dealer)

      assert ctx.table.round.participant_to_act_id != acting_participant_id
      refute ctx.table.round.participant_to_act_id == nil

      updated_participant =
        Enum.find(ctx.table.participants, &(&1.id == acting_participant_id))

      assert updated_participant.is_sitting_out == false
      assert updated_participant.status == :active

      scheduled_jobs = all_enqueued(worker: Poker.Tables.Jobs.TimeoutJob)

      refute Enum.any?(scheduled_jobs, fn job ->
               job.args["participant_id"] == acting_participant_id
             end)
    end

    test "player does not act - timeout fires, auto-fold and sit out", ctx do
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
