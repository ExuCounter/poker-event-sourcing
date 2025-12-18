defmodule Poker.Tables.Projectors.TableRoundsTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.TableRounds
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  setup ctx do
    ctx = ctx |> produce(:table) |> exec(:add_participants, generate_players: 3)

    ctx
  end

  describe "RoundStarted event" do
    test "creates a new round with correct values", ctx do
      ctx = ctx |> exec(:start_table)

      round_id = ctx.table.round.id

      assert_receive {:table, :round_started, %{table_id: _table_id, round_id: ^round_id}}

      round = Repo.get(TableRounds, round_id)

      assert round.id == round_id
      assert round.round_type == :pre_flop
      assert is_list(round.community_cards)
    end

    test "creates multiple rounds for different streets", ctx do
      ctx = ctx |> exec(:start_table) |> exec(:advance_round)

      flop_round_id = ctx.table.round.id

      assert_receive {:table, :round_started, %{table_id: _table_id, round_id: ^flop_round_id}}

      round = Repo.get(TableRounds, flop_round_id)

      assert round.round_type == :flop
      assert length(round.community_cards) == 3
    end
  end

  describe "ParticipantToActSelected event" do
    test "updates participant_to_act_id for current round", ctx do
      ctx = ctx |> exec(:start_table) |> exec(:advance_round)

      round_id = ctx.table.round.id

      assert_receive {:table, :participant_to_act_selected, %{table_id: _table_id, round_id: ^round_id, participant_id: participant_id}}

      round = Repo.get(TableRounds, round_id)

      assert round.participant_to_act_id != nil
      assert round.participant_to_act_id == participant_id
    end
  end
end
