defmodule Poker.Tables.Projectors.TableListTest do
  use Poker.DataCase
  alias Poker.Tables.Projections.TableList
  import Poker.DeckFixtures

  setup do
    Poker.Tables.PubSub.subscribe_to_table_list()
    on_exit(fn -> Poker.Tables.PubSub.unsubscribe_from_table_list() end)
  end

  describe "TableCreated event" do
    test "creates a new table list entry with correct initial values", ctx do
      ctx = ctx |> produce(:cash_game)

      table = Repo.get(TableList, ctx.table.id)

      assert_receive {:table_list, :table_created, %{table_id: _table_id}}

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
        |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :three_max})
        |> exec(:fill_tournament)

      assert_receive {:table_list, :table_created, %{table_id: _table_id}}

      assert_receive {:table_list, :participant_joined,
                      %{table_id: _table_id, participant_id: _participant_id1}}

      assert_receive {:table_list, :participant_joined,
                      %{table_id: _table_id, participant_id: _participant_id2}}

      assert_receive {:table_list, :participant_joined,
                      %{table_id: _table_id, participant_id: _participant_id3}}

      assert_receive {:table_list, :table_started, %{table_id: _table_id}}

      table = Repo.get(TableList, ctx.table.id)

      assert table.status == :live
      assert table.seated_count == 3
    end
  end

  describe "ParticipantBusted event" do
    test "seated count should decrease when participant busted", ctx do
      arrange_deck(%{
        dealer: [%{rank: :A, suit: :spades}, %{rank: :K, suit: :spades}],
        small_blind: [%{rank: 2, suit: :hearts}, %{rank: 7, suit: :clubs}],
        big_blind: [%{rank: 3, suit: :hearts}, %{rank: 8, suit: :clubs}],
        community: [
          %{rank: :Q, suit: :spades}, %{rank: :J, suit: :spades}, %{rank: :T, suit: :spades},
          %{rank: 2, suit: :diamonds}, %{rank: 3, suit: :diamonds}
        ]
      })

      ctx =
        ctx
        |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :three_max})
        |> exec(:fill_tournament)
        |> exec(:start_runout)

      assert_receive {:table_list, :participant_busted,
                      %{table_id: _table_id, participant_id: _participant_id}}

      assert_receive {:table_list, :participant_busted,
                      %{table_id: _table_id, participant_id: _participant_id}}

      table = Repo.get(TableList, ctx.table.id)

      assert table.seated_count == 1
    end
  end

  describe "TableFinished event" do
    test "table status should be changed to :finished when only one player left", ctx do
      arrange_deck(%{
        dealer: [%{rank: :A, suit: :spades}, %{rank: :K, suit: :spades}],
        big_blind: [%{rank: 2, suit: :hearts}, %{rank: 7, suit: :clubs}],
        community: [
          %{rank: :Q, suit: :spades}, %{rank: :J, suit: :spades}, %{rank: :T, suit: :spades},
          %{rank: 2, suit: :diamonds}, %{rank: 3, suit: :diamonds}
        ]
      })

      ctx =
        ctx
        |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
        |> exec(:fill_tournament)
        |> exec(:start_runout)

      assert_receive {:table_list, :table_finished, %{table_id: _table_id}}

      table = Repo.get(TableList, ctx.table.id)

      assert table.status == :finished
    end
  end
end
