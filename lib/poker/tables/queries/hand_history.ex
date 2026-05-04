defmodule Poker.Tables.Queries.HandHistory do
  @moduledoc """
  Queries for the global hand history list.

  Joins hand_summaries with hand_summary_participant_results to return
  all hands a player was dealt into, ordered most recent first.

  Uses cursor-based pagination for stable results. The cursor is
  `{inserted_at, hand_id}` from the last item on the previous page.
  """

  import Ecto.Query

  alias Poker.Tables.Projections.HandSummary
  alias Poker.Tables.Projections.HandSummaryParticipantResult

  @default_limit 20

  @doc """
  List all hands a player was dealt into, most recent first.

  ## Options
    * `:game_mode` - filter by `:cash_game` or `:tournament`
    * `:limit` - number of results (default #{@default_limit})
    * `:cursor` - `{inserted_at, hand_id}` from the last item of the previous page

  ## Returns

  `{items, next_cursor}` where `next_cursor` is `nil` when there are no more pages,
  or `{inserted_at, hand_id}` to pass as `:cursor` on the next call.
  """
  def list_for_player(player_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    game_mode = Keyword.get(opts, :game_mode)
    cursor = Keyword.get(opts, :cursor)

    base_query =
      from hand_summary in HandSummary,
        join: participant_result in HandSummaryParticipantResult,
        on:
          participant_result.hand_id == hand_summary.hand_id and
            participant_result.player_id == ^player_id,
        order_by: [desc: hand_summary.inserted_at, desc: hand_summary.hand_id],
        limit: ^(limit + 1),
        select: %{
          hand_id: hand_summary.hand_id,
          table_id: hand_summary.table_id,
          game_mode: hand_summary.game_mode,
          source_id: hand_summary.source_id,
          pot_total: hand_summary.pot_total,
          finish_reason: hand_summary.finish_reason,
          winner_player_id: hand_summary.winner_player_id,
          winner_hand_rank: hand_summary.winner_hand_rank,
          amount_won: participant_result.amount_won,
          amount_invested: participant_result.amount_invested,
          inserted_at: hand_summary.inserted_at
        }

    query =
      base_query
      |> maybe_filter_game_mode(game_mode)
      |> maybe_apply_cursor(cursor)

    rows = Poker.Repo.all(query)

    if length(rows) > limit do
      items = Enum.take(rows, limit)
      last = List.last(items)
      next_cursor = {last.inserted_at, last.hand_id}
      {items, next_cursor}
    else
      {rows, nil}
    end
  end

  defp maybe_filter_game_mode(query, nil), do: query

  defp maybe_filter_game_mode(query, game_mode) do
    where(query, [hand_summary, _participant_result], hand_summary.game_mode == ^game_mode)
  end

  defp maybe_apply_cursor(query, nil), do: query

  defp maybe_apply_cursor(query, {cursor_inserted_at, cursor_hand_id}) do
    where(
      query,
      [hand_summary, _participant_result],
      hand_summary.inserted_at < ^cursor_inserted_at or
        (hand_summary.inserted_at == ^cursor_inserted_at and
           hand_summary.hand_id < ^cursor_hand_id)
    )
  end
end
