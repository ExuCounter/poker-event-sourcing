defmodule Poker.Tables.Projectors.HandSummaryTest do
  use Poker.DataCase

  alias Poker.Tables.Projections.HandSummary
  alias Poker.Tables.Projections.HandSummaryParticipantResult

  alias Poker.Tables.Events.{
    HandStarted,
    HandFinished
  }

  describe "hand lifecycle - all_folded" do
    setup ctx do
      ctx
      |> exec(:create_tournament,
        settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max}
      )
      |> exec(:fill_tournament)
    end

    test "creates hand_summary on HandStarted", ctx do
      assert_receive_event(Poker.App, HandStarted, fn event ->
        assert event.table_id == ctx.table.id
      end)

      hand_id = ctx.table.hand.id

      assert %HandSummary{
               hand_id: ^hand_id,
               table_id: table_id,
               game_mode: :tournament,
               pot_total: 0,
               finish_reason: nil
             } = Repo.get_by!(HandSummary, hand_id: hand_id)

      assert table_id == ctx.table.id
    end

    test "creates participant results for all dealt players", ctx do
      assert_receive_event(Poker.App, HandStarted, fn event ->
        assert event.table_id == ctx.table.id
      end)

      hand_id = ctx.table.hand.id

      results =
        Repo.all(from result in HandSummaryParticipantResult, where: result.hand_id == ^hand_id)

      assert length(results) == 2
      assert Enum.all?(results, fn result -> result.amount_won == 0 end)
    end

    test "sets pot_total, winner_player_id, and finish_reason after hand finishes", ctx do
      hand_id = ctx.table.hand.id

      ctx |> exec(:fold_hand, position: :dealer)

      assert_receive_event(Poker.App, HandFinished, fn event ->
        assert event.hand_id == hand_id
      end)

      assert %HandSummary{
               finish_reason: :all_folded,
               winner_hand_rank: nil,
               winner_player_id: winner_player_id,
               pot_total: pot_total
             } = Repo.get_by!(HandSummary, hand_id: hand_id)

      assert pot_total > 0
      assert is_binary(winner_player_id)
    end

    test "winner participant result has amount_won equal to pot_total", ctx do
      hand_id = ctx.table.hand.id

      ctx |> exec(:fold_hand, position: :dealer)

      assert_receive_event(Poker.App, HandFinished, fn event ->
        assert event.hand_id == hand_id
      end)

      %HandSummary{winner_player_id: winner_player_id, pot_total: pot_total} =
        Repo.get_by!(HandSummary, hand_id: hand_id)

      assert %HandSummaryParticipantResult{amount_won: ^pot_total} =
               Repo.get_by!(HandSummaryParticipantResult,
                 hand_id: hand_id,
                 player_id: winner_player_id
               )
    end

    test "loser participant result has amount_won of 0", ctx do
      hand_id = ctx.table.hand.id

      ctx |> exec(:fold_hand, position: :dealer)

      assert_receive_event(Poker.App, HandFinished, fn event ->
        assert event.hand_id == hand_id
      end)

      %HandSummary{winner_player_id: winner_player_id} =
        Repo.get_by!(HandSummary, hand_id: hand_id)

      assert %HandSummaryParticipantResult{amount_won: 0} =
               from(result in HandSummaryParticipantResult,
                 where: result.hand_id == ^hand_id and result.player_id != ^winner_player_id
               )
               |> Repo.one!()
    end
  end
end
