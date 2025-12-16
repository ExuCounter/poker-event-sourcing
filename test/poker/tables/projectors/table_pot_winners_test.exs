defmodule Poker.Tables.Projectors.TablePotWinnersTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.TablePotWinners
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  setup ctx do
    ctx = ctx |> produce(:table) |> exec(:add_participants, generate_players: 3)

    subscribe_to_pot_winners(ctx.table.id)

    on_exit(fn -> unsubscribe_from_pot_winners(ctx.table.id) end)

    ctx
  end

  describe "HandFinished event" do
    test "creates pot winners and broadcasts winner data", ctx do
      ctx = ctx |> setup_winning_hand() |> exec(:start_table) |> exec(:start_runout)

      assert_pot_winner_event!(:pot_winners_determined)

      hand_id = ctx.table.hand.id

      # Verify database records
      db_winners = Repo.all(from w in TablePotWinners, where: w.hand_id == ^hand_id)

      assert length(db_winners) > 0

      Enum.each(db_winners, fn winner ->
        assert winner.hand_id == hand_id
        assert winner.pot_id
        assert winner.participant_id
        assert winner.amount > 0
      end)
    end
  end

  defp subscribe_to_pot_winners(table_id) do
    Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}:pot_winners")
  end

  defp unsubscribe_from_pot_winners(table_id) do
    Phoenix.PubSub.unsubscribe(Poker.PubSub, "table:#{table_id}:pot_winners")
  end

  defp assert_pot_winner_event!(event) do
    receive do
      {^event, _data} -> :ok
    after
      1000 -> raise "#{event} was not received"
    end
  end
end
