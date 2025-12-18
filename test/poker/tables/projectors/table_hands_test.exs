defmodule Poker.Tables.Projectors.TableHandsTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.TableHands
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  setup ctx do
    ctx |> produce(:table) |> exec(:add_participants, generate_players: 3)
  end

  describe "HandStarted event" do
    test "creates a new hand with active status", ctx do
      ctx = ctx |> exec(:start_table)

      hand_id = ctx.table.hand.id

      assert_receive {:table, :hand_started, %{table_id: _table_id, hand_id: ^hand_id}}

      hand = Repo.get(TableHands, hand_id)

      assert hand.id == hand_id
      assert hand.table_id == ctx.table.id
      assert hand.status == :active
    end
  end

  describe "HandFinished event" do
    test "updates hand status to finished when hand completes", ctx do
      ctx = ctx |> setup_winning_hand() |> exec(:start_table) |> exec(:start_runout)

      hand_id = ctx.table.hand.id

      assert_receive {:table, :hand_finished, %{table_id: _table_id, hand_id: ^hand_id}}

      hand = Repo.get(TableHands, hand_id)

      assert hand.status == :finished
    end
  end
end
