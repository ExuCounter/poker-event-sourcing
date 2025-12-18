defmodule Poker.Tables.Projectors.TableTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.Table
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  setup ctx do
    ctx |> produce(:table)
  end

  describe "TableCreated event" do
    test "creates a new table with correct initial status", ctx do
      table = Repo.get(Table, ctx.table.id)

      assert table.id == ctx.table.id
      assert table.status == :waiting
    end
  end

  describe "TableStarted event" do
    test "updates table status to live when table starts", ctx do
      ctx =
        ctx
        |> exec(:add_participants, generate_players: 3)
        |> exec(:start_table)

      assert_receive {:table, :table_started, %{table_id: _table_id}}

      table = Repo.get(Table, ctx.table.id)

      assert table.status == :live
    end
  end

  describe "TableFinished event" do
    test "updates table status to finished when table finishes", ctx do
      ctx =
        ctx
        |> exec(:add_participants, generate_players: 2)
        |> setup_winning_hand()
        |> exec(:start_table)
        |> exec(:start_runout)

      assert_receive {:table, :table_finished, %{table_id: _table_id}}

      table = Repo.get(Table, ctx.table.id)

      assert table.status == :finished
    end
  end
end
