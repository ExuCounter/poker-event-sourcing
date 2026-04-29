defmodule Poker.Tables.Projectors.HandHistoryTest do
  use Poker.DataCase

  alias Poker.Tables.Projections.HandHistory
  alias Poker.Tables.Aggregates.Table

  alias Poker.Tables.Events.{
    HandStarted,
    HandFinished
  }

  describe "HandStarted event" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "creates hand history with initial state from event store", ctx do
      assert_receive_event(Poker.App, HandStarted, fn event ->
        assert event.table_id == ctx.table.id
      end)

      hand_id = ctx.table.hand.id

      hand_history = Repo.get_by(HandHistory, hand_id: hand_id)

      assert hand_history.hand_id == hand_id
      assert hand_history.table_id == ctx.table.id
      assert hand_history.start_version > 0
      assert hand_history.end_version == nil

      initial_state = :erlang.binary_to_term(hand_history.initial_state)
      assert %Table{} = initial_state
      assert initial_state.id == ctx.table.id
      assert length(initial_state.participants) == 2
    end
  end

  describe "HandFinished event" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "sets end_version on hand history", ctx do
      hand_id = ctx.table.hand.id

      ctx
      |> exec(:fold_hand, position: :dealer)

      assert_receive_event(Poker.App, HandFinished, fn event ->
        assert event.hand_id == hand_id
      end)

      hand_history = Repo.get_by(HandHistory, hand_id: hand_id)

      assert hand_history.end_version > hand_history.start_version
    end
  end

  describe "second hand" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "rebuilds state from previous hand history", ctx do
      first_hand_id = ctx.table.hand.id

      ctx =
        ctx
        |> exec(:fold_hand, position: :dealer)

      assert_receive_event(Poker.App, HandFinished, fn event ->
        assert event.hand_id == first_hand_id
      end)

      second_hand_id = ctx.table.hand.id
      assert second_hand_id != first_hand_id

      second_hand = Repo.get_by(HandHistory, hand_id: second_hand_id)

      assert second_hand.start_version > 0
      assert second_hand.end_version == nil

      initial_state = :erlang.binary_to_term(second_hand.initial_state)
      assert %Table{} = initial_state
      assert initial_state.id == ctx.table.id
    end
  end
end
