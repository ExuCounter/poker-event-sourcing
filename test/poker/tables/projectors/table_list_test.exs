defmodule Poker.Tables.Projectors.TableListTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.TableList
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  setup do
    Phoenix.PubSub.subscribe(Poker.PubSub, "table_list")
    on_exit(fn -> Phoenix.PubSub.unsubscribe(Poker.PubSub, "table_list") end)
  end

  describe "TableCreated event" do
    test "creates a new table list entry with correct initial values", ctx do
      ctx = ctx |> exec(:create_table, type: :six_max)

      table = Repo.get(TableList, ctx.table.id)

      assert_table_list_event!(:table_created)

      assert table.id == ctx.table.id
      assert table.status == :waiting
      assert table.seated_count == 0
      assert table.seats_count == 6
    end
  end

  describe "TableStarted event" do
    test "updates table entry when starting the table", ctx do
      ctx =
        ctx
        |> produce(:table)
        |> exec(:add_participants, generate_players: 3)
        |> exec(:start_table)

      assert_table_list_event!(:table_started)

      table = Repo.get(TableList, ctx.table.id)

      assert table.status == :live
      assert table.seated_count == 3
    end
  end

  describe "ParticipantBusted event" do
    test "seated count should deacrease when participant busted", ctx do
      ctx =
        ctx
        |> produce(:table)
        |> exec(:add_participants, generate_players: 3)
        |> setup_winning_hand()
        |> exec(:start_table)
        |> exec(:start_runout)

      assert_table_list_event!(:participant_busted)
      assert_table_list_event!(:participant_busted)

      table = Repo.get(TableList, ctx.table.id)

      assert table.seated_count == 1
    end
  end

  describe "TableFinished event" do
    test "table status should be changed to :finished when only one player left", ctx do
      ctx =
        ctx
        |> produce(:table)
        |> exec(:add_participants, generate_players: 2)
        |> setup_winning_hand()
        |> exec(:start_table)
        |> exec(:start_runout)

      assert_table_list_event!(:table_finished)

      table = Repo.get(TableList, ctx.table.id)

      assert table.status == :finished
    end
  end

  defp assert_table_list_event!(event) do
    receive do
      {:table_list_updated, _table_id, ^event} -> :ok
    after
      1000 -> raise "#{event} was not received"
    end
  end
end
