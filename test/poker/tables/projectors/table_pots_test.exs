defmodule Poker.Tables.Projectors.TablePotsTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.TablePots
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  setup ctx do
    ctx = ctx |> produce(:table) |> exec(:add_participants, generate_players: 3)

    ctx
  end

  describe "PotsRecalculated event" do
    test "creates pots and broadcasts pot data", ctx do
      ctx = ctx |> exec(:start_table)

      assert_receive {:table, :pots_updated, %{table_id: _table_id, hand_id: hand_id, pots: pots}}

      assert hand_id == ctx.table.hand.id
      assert length(pots) > 0

      # Verify database records
      db_pots = Repo.all(from p in TablePots, where: p.hand_id == ^ctx.table.hand.id)

      assert length(db_pots) > 0

      Enum.each(db_pots, fn db_pot ->
        assert db_pot.hand_id == ctx.table.hand.id
        assert db_pot.amount > 0
      end)
    end
  end
end
