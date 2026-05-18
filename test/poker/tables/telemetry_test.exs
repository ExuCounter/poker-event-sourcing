defmodule Poker.Tables.TelemetryTest do
  use Poker.DataCase, async: false

  describe "raise_hand telemetry" do
    setup ctx do
      ctx
      |> exec(:create_tournament,
        settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :three_max}
      )
      |> exec(:fill_tournament)
    end

    setup do
      test_pid = self()
      handler_id = "telemetry-test-#{inspect(self())}"

      :telemetry.attach_many(
        handler_id,
        [
          [:poker, :command, :raise, :start],
          [:poker, :command, :raise, :stop],
          [:poker, :command, :raise, :exception]
        ],
        fn event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)
    end

    test "emits :start and :stop events with metadata", ctx do
      table = ctx.table

      acting_participant =
        Enum.find(table.participants, &(&1.id == table.round.participant_to_act_id))

      table_id = table.id
      player_id = acting_participant.player_id
      amount = 40

      assert :ok = Poker.Tables.raise_hand(table_id, player_id, amount)

      assert_received {:telemetry, [:poker, :command, :raise, :start], _, start_meta}
      assert start_meta.table_id == table_id
      assert start_meta.player_id == player_id
      assert start_meta.amount == amount
      assert is_binary(start_meta.hand_action_id)

      assert_received {:telemetry, [:poker, :command, :raise, :stop], measurements, _stop_meta}
      assert is_integer(measurements.duration)
    end
  end
end
