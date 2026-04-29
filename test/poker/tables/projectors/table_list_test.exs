defmodule Poker.Tables.Projectors.TableListTest do
  use Poker.DataCase

  alias Poker.Tables.Projectors.TableList, as: Projector
  alias Poker.Tables.Projections.TableList

  alias Poker.Tables.Events.{
    TableCreated,
    TableStarted,
    ParticipantJoined,
    ParticipantBusted,
    TableFinished,
    TablePaused,
    TableResumed
  }

  setup do
    Poker.Tables.PubSub.subscribe_to_table_list()
    on_exit(fn -> Poker.Tables.PubSub.unsubscribe_from_table_list() end)
  end

  defp metadata do
    %{handler_name: "table_list_test", event_number: :erlang.unique_integer([:positive, :monotonic])}
  end

  defp create_table(opts \\ %{}) do
    table_id = opts[:table_id] || Ecto.UUID.generate()

    event = %TableCreated{
      id: table_id,
      status: :waiting,
      table_type: opts[:table_type] || :six_max,
      game_mode: opts[:game_mode] || :tournament,
      source_id: opts[:source_id] || Ecto.UUID.generate()
    }

    :ok = Projector.handle(event, metadata())
    table_id
  end

  defp join_participant(table_id, opts \\ %{}) do
    participant_id = opts[:participant_id] || Ecto.UUID.generate()

    event = %ParticipantJoined{
      id: participant_id,
      table_id: table_id,
      player_id: opts[:player_id] || Ecto.UUID.generate(),
      seat_number: opts[:seat_number] || 1
    }

    :ok = Projector.handle(event, metadata())
    participant_id
  end

  describe "TableCreated event" do
    test "creates a new table list entry with correct initial values" do
      table_id = create_table()

      assert_receive {:table_list, :table_created, %{table_id: ^table_id}}

      table = Repo.get(TableList, table_id)

      assert table.id == table_id
      assert table.status == :waiting
      assert table.seated_count == 0
      assert table.seats_count == 6
    end
  end

  describe "TableStarted event" do
    test "updates table status to live" do
      table_id = create_table(table_type: :three_max)
      join_participant(table_id, seat_number: 1)
      join_participant(table_id, seat_number: 2)
      join_participant(table_id, seat_number: 3)

      :ok = Projector.handle(%TableStarted{id: table_id, status: :live}, metadata())

      assert_receive {:table_list, :table_started, %{table_id: ^table_id}}

      table = Repo.get(TableList, table_id)

      assert table.status == :live
      assert table.seated_count == 3
    end
  end

  describe "ParticipantJoined event" do
    test "increments seated count" do
      table_id = create_table()
      participant_id = join_participant(table_id)

      assert_receive {:table_list, :participant_joined, %{table_id: ^table_id, participant_id: ^participant_id}}

      table = Repo.get(TableList, table_id)

      assert table.seated_count == 1
    end
  end

  describe "ParticipantBusted event" do
    test "decrements seated count" do
      table_id = create_table(table_type: :three_max)
      participant_id_1 = join_participant(table_id, seat_number: 1)
      join_participant(table_id, seat_number: 2)
      join_participant(table_id, seat_number: 3)

      :ok = Projector.handle(%ParticipantBusted{table_id: table_id, participant_id: participant_id_1, player_id: Ecto.UUID.generate()}, metadata())

      assert_receive {:table_list, :participant_busted, %{table_id: ^table_id, participant_id: ^participant_id_1}}

      table = Repo.get(TableList, table_id)

      assert table.seated_count == 2
    end
  end

  describe "TableFinished event" do
    test "updates table status to finished" do
      table_id = create_table()

      :ok = Projector.handle(%TableFinished{table_id: table_id}, metadata())

      assert_receive {:table_list, :table_finished, %{table_id: ^table_id}}

      table = Repo.get(TableList, table_id)

      assert table.status == :finished
    end
  end

  describe "TablePaused event" do
    test "updates table status to paused" do
      table_id = create_table()

      :ok = Projector.handle(%TablePaused{table_id: table_id}, metadata())

      assert_receive {:table_list, :table_paused, %{table_id: ^table_id}}

      table = Repo.get(TableList, table_id)

      assert table.status == :paused
    end
  end

  describe "TableResumed event" do
    test "updates table status to live" do
      table_id = create_table()
      :ok = Projector.handle(%TablePaused{table_id: table_id}, metadata())

      :ok = Projector.handle(%TableResumed{table_id: table_id}, metadata())

      assert_receive {:table_list, :table_resumed, %{table_id: ^table_id}}

      table = Repo.get(TableList, table_id)

      assert table.status == :live
    end
  end
end
