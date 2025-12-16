defmodule Poker.Tables.Projectors.TableRoundsTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.TableRounds
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  setup ctx do
    ctx = ctx |> produce(:table) |> exec(:add_participants, generate_players: 3)

    subscribe_to_rounds(ctx.table.id)

    on_exit(fn -> unsubscribe_from_rounds(ctx.table.id) end)

    ctx
  end

  describe "RoundStarted event" do
    test "creates a new round with correct values", ctx do
      ctx = ctx |> exec(:start_table)

      round_id = ctx.table.round.id

      assert_round_event!(round_id, :round_started)

      round = Repo.get(TableRounds, round_id)

      assert round.id == round_id
      assert round.round_type == :pre_flop
      assert is_list(round.community_cards)
    end

    test "creates multiple rounds for different streets", ctx do
      ctx = ctx |> exec(:start_table) |> exec(:advance_round)

      flop_round_id = ctx.table.round.id

      assert_round_event!(flop_round_id, :round_started)

      round = Repo.get(TableRounds, flop_round_id)

      assert round.round_type == :flop
      assert length(round.community_cards) == 3
    end
  end

  describe "ParticipantToActSelected event" do
    test "updates participant_to_act_id for current round", ctx do
      ctx = ctx |> exec(:start_table) |> exec(:advance_round)

      round_id = ctx.table.round.id

      assert_round_event!(round_id, :participant_to_act_selected)

      round = Repo.get(TableRounds, round_id)

      assert round.participant_to_act_id != nil
    end
  end

  defp subscribe_to_rounds(table_id) do
    Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}:rounds")
  end

  defp unsubscribe_from_rounds(table_id) do
    Phoenix.PubSub.unsubscribe(Poker.PubSub, "table:#{table_id}:rounds")
  end

  defp assert_round_event!(round_id, event) do
    receive do
      {:round_updated, ^round_id, ^event} -> :ok
    after
      1000 -> raise "#{event} was not received for round #{round_id}"
    end
  end
end
