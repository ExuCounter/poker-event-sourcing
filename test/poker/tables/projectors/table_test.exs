defmodule Poker.Tables.Projectors.TableTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.Table
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  setup ctx do
    ctx = ctx |> produce(:table)

    subscribe_to_table(ctx.table.id)

    on_exit(fn -> unsubscribe_from_table(ctx.table.id) end)

    ctx
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

      assert_table_event!(ctx.table.id, :table_started)

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

      assert_table_event!(ctx.table.id, :table_finished)

      table = Repo.get(Table, ctx.table.id)

      assert table.status == :finished
    end
  end

  defp subscribe_to_table(table_id) do
    Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}")
  end

  defp unsubscribe_from_table(table_id) do
    Phoenix.PubSub.unsubscribe(Poker.PubSub, "table:#{table_id}")
  end

  defp assert_table_event!(table_id, event) do
    receive do
      {:table_updated, ^event} -> :ok
    after
      1000 ->
        raise "#{event} was not received for table #{table_id}"
    end
  end
end
