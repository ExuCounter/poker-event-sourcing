defmodule Poker.Tables.Projectors.TablePotWinnersTest do
  use Poker.DataCase
  alias Poker.Tables.Projections.TablePotWinners
  import Poker.DeckFixtures

  setup ctx do
    ctx |> produce(:table) |> exec(:add_participants, generate_players: 3)
  end

  describe "HandFinished event" do
    test "creates pot winners and broadcasts winner data", ctx do
      ctx = ctx |> setup_winning_hand() |> exec(:start_table) |> exec(:start_runout)

      assert_receive {:table, :pot_winners_determined,
                      %{table_id: _table_id, hand_id: hand_id, winners: winners}}

      assert hand_id == ctx.table.hand.id
      assert length(winners) > 0

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
end
