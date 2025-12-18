defmodule Poker.Tables.Projectors.TablePotsTest do
  use Poker.DataCase
  alias Poker.Tables.Projections.TablePots
  import Poker.DeckFixtures

  describe "PotsRecalculated event" do
    setup ctx do
      ctx |> produce(:table) |> exec(:add_participants, generate_players: 3)
    end

    test "creates pots and broadcasts pot data", ctx do
      ctx = ctx |> exec(:start_table)

      assert_receive {:table, :pots_updated, %{table_id: _table_id, hand_id: hand_id, pots: pots}}

      assert hand_id == ctx.table.hand.id
      assert length(pots) > 0

      db_pots = Repo.all(from(p in TablePots))

      assert length(db_pots) > 0

      Enum.each(db_pots, fn db_pot ->
        assert db_pot.hand_id == ctx.table.hand.id
        assert db_pot.amount > 0
      end)
    end
  end

  test "Pots recalculate event", ctx do
    ctx =
      ctx |> produce(:table) |> exec(:add_participants, generate_players: 2) |> exec(:start_table)

    ctx =
      ctx
      |> exec(:raise_hand, amount: 100)
      |> exec(:call_hand)
      |> exec(:raise_hand, amount: 100)
      |> exec(:call_hand)
      |> exec(:raise_hand, amount: 50)
      |> exec(:call_hand)

    db_pots = Repo.all(from(p in TablePots))

    dbg(db_pots)
  end
end
