defmodule Poker.Tables.Projectors.TableLobbyTest do
  use Poker.DataCase
  alias Poker.Tables.Projections.TableLobby
  import Poker.DeckFixtures

  describe "ParticipantJoined event" do
    test "adds participant to lobby and increments seated count", ctx do
      ctx =
        ctx
        |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
        |> exec(:fill_tournament)

      Poker.Tables.PubSub.subscribe_to_lobby(ctx.table.id)

      assert_receive {:table_lobby, :participant_joined,
                      %{
                        table_id: _table_id,
                        participant_id: _participant_id
                      }}

      table = Repo.get(TableLobby, ctx.table.id)

      assert table.seated_count == 2
      assert length(table.participants) == 2

      participant = hd(table.participants)
      assert participant.player_id
      assert participant.email
    end
  end

  describe "TableStarted event" do
    test "updates table status when starting the table", ctx do
      ctx =
        ctx
        |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :three_max})
        |> exec(:fill_tournament)

      Poker.Tables.PubSub.subscribe_to_lobby(ctx.table.id)

      assert_receive {:table_lobby, :table_started, %{table_id: _table_id}}

      table = Repo.get(TableLobby, ctx.table.id)

      assert table.status == :live
      assert table.seated_count == 3
      assert length(table.participants) == 3
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

      Poker.Tables.PubSub.subscribe_to_lobby(ctx.table.id)

      ctx = ctx |> exec(:start_runout)

      assert_receive {:table_lobby, :participant_busted,
                      %{table_id: _table_id, participant_id: _participant_id}}

      assert_receive {:table_lobby, :participant_busted,
                      %{table_id: _table_id, participant_id: _participant_id}}

      table = Repo.get(TableLobby, ctx.table.id)

      assert table.seated_count == 1
      assert length(table.participants) == 3
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

      Poker.Tables.PubSub.subscribe_to_lobby(ctx.table.id)

      ctx = ctx |> exec(:start_runout)

      assert_receive {:table_lobby, :table_finished, %{table_id: _table_id}}
      table = Repo.get(TableLobby, ctx.table.id)

      assert table.status == :finished
    end
  end
end
