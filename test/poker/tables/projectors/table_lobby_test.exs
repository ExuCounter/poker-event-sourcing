defmodule Poker.Tables.Projectors.TableLobbyTest do
  use Poker.DataCase

  alias Poker.Tables.Projectors.TableLobby, as: Projector
  alias Poker.Tables.Projections.TableLobby

  alias Poker.Tables.Events.{
    TableCreated,
    TableStarted,
    ParticipantJoined,
    ParticipantBusted,
    ParticipantLeft,
    TableFinished,
    TablePaused,
    TableResumed
  }

  defp metadata do
    %{handler_name: "table_lobby_test", event_number: :erlang.unique_integer([:positive, :monotonic])}
  end

  defp create_table(opts \\ %{}) do
    table_id = opts[:table_id] || Ecto.UUID.generate()

    event = %TableCreated{
      id: table_id,
      status: :waiting,
      table_type: opts[:table_type] || :six_max,
      small_blind: opts[:small_blind] || 10,
      big_blind: opts[:big_blind] || 20,
      starting_stack: opts[:starting_stack] || 1000,
      creator_id: opts[:creator_id] || Ecto.UUID.generate()
    }

    :ok = Projector.handle(event, metadata())
    table_id
  end

  defp create_user(ctx) do
    ctx |> produce(player: [:active])
  end

  defp join_participant(table_id, player, opts \\ %{}) do
    participant_id = opts[:participant_id] || Ecto.UUID.generate()

    event = %ParticipantJoined{
      id: participant_id,
      table_id: table_id,
      player_id: player.id,
      seat_number: opts[:seat_number] || 1
    }

    :ok = Projector.handle(event, metadata())
    participant_id
  end

  describe "TableCreated event" do
    test "creates a new table lobby entry" do
      table_id = create_table(small_blind: 10, big_blind: 20, starting_stack: 1000, table_type: :six_max)

      table = Repo.get(TableLobby, table_id)

      assert table.status == :waiting
      assert table.small_blind == 10
      assert table.big_blind == 20
      assert table.starting_stack == 1000
      assert table.table_type == :six_max
      assert table.seated_count == 0
      assert table.seats_count == 6
      assert table.participants == []
    end
  end

  describe "ParticipantJoined event" do
    test "adds participant to lobby and increments seated count", ctx do
      table_id = create_table(table_type: :two_max)

      Poker.Tables.PubSub.subscribe_to_lobby(table_id)

      ctx = create_user(ctx)
      participant_id = join_participant(table_id, ctx.player, seat_number: 1)

      assert_receive {:table_lobby, :participant_joined, %{table_id: ^table_id, participant_id: ^participant_id}}

      table = Repo.get(TableLobby, table_id)

      assert table.seated_count == 1
      assert length(table.participants) == 1

      participant = hd(table.participants)
      assert participant.player_id == ctx.player.id
      assert participant.email == ctx.player.email
      assert participant.nickname == ctx.player.nickname
      assert participant.seat_number == 1
    end
  end

  describe "TableStarted event" do
    test "updates table status to live", ctx do
      table_id = create_table(table_type: :three_max)

      ctx = create_user(ctx)
      join_participant(table_id, ctx.player, seat_number: 1)

      Poker.Tables.PubSub.subscribe_to_lobby(table_id)

      :ok = Projector.handle(%TableStarted{id: table_id, status: :live}, metadata())

      assert_receive {:table_lobby, :table_started, %{table_id: ^table_id}}

      table = Repo.get(TableLobby, table_id)

      assert table.status == :live
    end
  end

  describe "ParticipantBusted event" do
    test "marks participant as busted and decrements seated count", ctx do
      table_id = create_table(table_type: :two_max)

      ctx = create_user(ctx)
      participant_id = join_participant(table_id, ctx.player, seat_number: 1)

      Poker.Tables.PubSub.subscribe_to_lobby(table_id)

      :ok = Projector.handle(%ParticipantBusted{table_id: table_id, participant_id: participant_id, player_id: ctx.player.id}, metadata())

      assert_receive {:table_lobby, :participant_busted, %{table_id: ^table_id, participant_id: ^participant_id}}

      table = Repo.get(TableLobby, table_id)

      assert table.seated_count == 0
      assert length(table.participants) == 1
      assert hd(table.participants).status == :busted
    end
  end

  describe "ParticipantLeft event" do
    test "removes participant from list and decrements seated count", ctx do
      table_id = create_table(table_type: :two_max)

      ctx = create_user(ctx)
      participant_id = join_participant(table_id, ctx.player, seat_number: 1)

      Poker.Tables.PubSub.subscribe_to_lobby(table_id)

      :ok = Projector.handle(%ParticipantLeft{table_id: table_id, participant_id: participant_id, player_id: ctx.player.id}, metadata())

      assert_receive {:table_lobby, :participant_left, %{table_id: ^table_id, participant_id: ^participant_id}}

      table = Repo.get(TableLobby, table_id)

      assert table.seated_count == 0
      assert table.participants == []
    end
  end

  describe "TableFinished event" do
    test "updates table status to finished" do
      table_id = create_table()

      Poker.Tables.PubSub.subscribe_to_lobby(table_id)

      :ok = Projector.handle(%TableFinished{table_id: table_id}, metadata())

      assert_receive {:table_lobby, :table_finished, %{table_id: ^table_id}}

      table = Repo.get(TableLobby, table_id)

      assert table.status == :finished
    end
  end

  describe "TablePaused event" do
    test "updates table status to paused" do
      table_id = create_table()

      Poker.Tables.PubSub.subscribe_to_lobby(table_id)

      :ok = Projector.handle(%TablePaused{table_id: table_id}, metadata())

      assert_receive {:table_lobby, :table_paused, %{table_id: ^table_id}}

      table = Repo.get(TableLobby, table_id)

      assert table.status == :paused
    end
  end

  describe "TableResumed event" do
    test "updates table status to live" do
      table_id = create_table()
      :ok = Projector.handle(%TablePaused{table_id: table_id}, metadata())

      Poker.Tables.PubSub.subscribe_to_lobby(table_id)

      :ok = Projector.handle(%TableResumed{table_id: table_id}, metadata())

      assert_receive {:table_lobby, :table_resumed, %{table_id: ^table_id}}

      table = Repo.get(TableLobby, table_id)

      assert table.status == :live
    end
  end
end
