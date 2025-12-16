defmodule Poker.Tables.Projectors.TablePotsTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.TablePots
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  setup ctx do
    ctx = ctx |> produce(:table) |> exec(:add_participants, generate_players: 3)

    subscribe_to_pots(ctx.table.id)

    on_exit(fn -> unsubscribe_from_pots(ctx.table.id) end)

    ctx
  end

  describe "PotsRecalculated event" do
    test "creates pots and broadcasts pot data", ctx do
      ctx = ctx |> exec(:start_table)

      assert_pot_event!(:pots_updated)

      # Verify database records
      db_pots = Repo.all(from p in TablePots, where: p.hand_id == ^ctx.table.hand.id)

      assert length(db_pots) > 0

      Enum.each(db_pots, fn db_pot ->
        assert db_pot.hand_id == ctx.table.hand.id
        assert db_pot.amount > 0
      end)
    end
  end

  defp subscribe_to_pots(table_id) do
    Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}:pots")
  end

  defp unsubscribe_from_pots(table_id) do
    Phoenix.PubSub.unsubscribe(Poker.PubSub, "table:#{table_id}:pots")
  end

  defp assert_pot_event!(event) do
    receive do
      {^event, _data} -> :ok
    after
      1000 -> raise "#{event} was not received"
    end
  end
end
