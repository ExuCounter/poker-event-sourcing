defmodule Poker.Tables.Projectors.TableLobbyTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.TableLobby
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  setup ctx do
    ctx = ctx |> produce(:table)

    Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{ctx.table.id}:lobby")
    on_exit(fn -> Phoenix.PubSub.unsubscribe(Poker.PubSub, "table:#{ctx.table.id}:lobby") end)

    ctx
  end

  describe "ParticipantJoined event" do
    test "adds participant to lobby and increments seated count", ctx do
      ctx = ctx |> exec(:add_participants, generate_players: 1)

      assert_receive {:table_lobby, :participant_joined,
                      %{
                        table_id: _table_id,
                        participant_id: _participant_id
                      }}

      table = Repo.get(TableLobby, ctx.table.id)

      assert table.seated_count == 1
      assert length(table.participants) == 1

      participant = hd(table.participants)
      assert participant.player_id
      assert participant.email
    end
  end

  describe "TableStarted event" do
    test "updates table status when starting the table", ctx do
      ctx = ctx |> exec(:add_participants, generate_players: 3) |> exec(:start_table)

      assert_receive {:table_lobby, :table_started, %{table_id: _table_id}}

      table = Repo.get(TableLobby, ctx.table.id)

      assert table.status == :live
      assert table.seated_count == 3
      assert length(table.participants) == 3
    end
  end

  describe "ParticipantBusted event" do
    test "seated count should decrease when participant busted", ctx do
      ctx =
        ctx
        |> exec(:add_participants, generate_players: 3)
        |> setup_winning_hand()
        |> exec(:start_table)
        |> exec(:start_runout)

      assert_receive {:table_lobby, :participant_busted,
                      %{table_id: _table_id, participant_id: _participant_id}}

      assert_receive {:table_lobby, :participant_busted,
                      %{table_id: _table_id, participant_id: _participant_id}}

      table = Repo.get(TableLobby, ctx.table.id)

      assert table.seated_count == 1
      # Note: participants list doesn't remove busted players, only seated_count changes
      assert length(table.participants) == 3
    end
  end

  describe "TableFinished event" do
    test "table status should be changed to :finished when only one player left", ctx do
      ctx =
        ctx
        |> exec(:add_participants, generate_players: 2)
        |> setup_winning_hand()
        |> exec(:start_table)
        |> exec(:start_runout)

      assert_receive {:table_lobby, :table_finished, %{table_id: _table_id}}
      table = Repo.get(TableLobby, ctx.table.id)

      assert table.status == :finished
    end
  end
end
