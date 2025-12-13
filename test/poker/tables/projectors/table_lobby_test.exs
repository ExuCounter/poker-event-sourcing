defmodule Poker.Tables.Projectors.TableLobbyTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.TableLobby
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  setup ctx do
    ctx = ctx |> produce(:table)

    subscribe_to_lobby(ctx.table.id)

    on_exit(fn -> unsubscribe_from_lobby(ctx.table.id) end)

    ctx
  end

  describe "ParticipantJoined event" do
    test "adds participant to lobby and increments seated count", ctx do
      ctx = ctx |> exec(:add_participants, generate_players: 1)

      assert_lobby_event!(ctx.table.id, :participant_joined)

      table = Repo.get(TableLobby, ctx.table.id)

      assert table.seated_count == 1
      assert length(table.participants) == 1

      participant = hd(table.participants)
      assert participant.player_id
      assert participant.email
    end

    test "adds multiple participants correctly", ctx do
      ctx = ctx |> exec(:add_participants, generate_players: 3)

      assert_lobby_event!(ctx.table.id, :participant_joined)
      assert_lobby_event!(ctx.table.id, :participant_joined)
      assert_lobby_event!(ctx.table.id, :participant_joined)

      table = Repo.get(TableLobby, ctx.table.id)

      assert table.seated_count == 3
      assert length(table.participants) == 3

      # Verify all participants have required fields
      Enum.each(table.participants, fn participant ->
        assert participant.player_id
        assert participant.email
      end)
    end
  end

  describe "TableStarted event" do
    test "updates table status when starting the table", ctx do
      ctx = ctx |> exec(:add_participants, generate_players: 3) |> exec(:start_table)

      assert_lobby_event!(ctx.table.id, :table_started)

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

      assert_lobby_event!(ctx.table.id, :participant_busted)
      assert_lobby_event!(ctx.table.id, :participant_busted)

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

      assert_lobby_event!(ctx.table.id, :table_finished)

      table = Repo.get(TableLobby, ctx.table.id)

      assert table.status == :finished
    end
  end

  defp subscribe_to_lobby(table_id) do
    Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}:lobby")
  end

  defp unsubscribe_from_lobby(table_id) do
    Phoenix.PubSub.unsubscribe(Poker.PubSub, "table:#{table_id}:lobby")
  end

  defp assert_lobby_event!(table_id, event) do
    receive do
      {:lobby_updated, ^event} -> :ok
    after
      1000 -> raise "#{event} was not received for table #{table_id}"
    end
  end
end
