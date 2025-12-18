defmodule Poker.Tables.TableTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.Table

  setup do
    Mox.set_mox_global()
  end

  test "test", ctx do
    ctx =
      ctx
      |> exec(:add_participants, generate_players: 2)
      |> exec(:start_table)
      |> exec(:start_runout)

    table = Poker.Tables.get_table(ctx.table.id)
    dbg(table)
  end
end
