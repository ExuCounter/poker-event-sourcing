defmodule Poker.Tables.Jobs.AutoFoldJob do
  use Oban.Worker, queue: :tables, max_attempts: 1

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"table_id" => table_id, "player_id" => player_id}}) do
    Poker.Tables.fold_hand(table_id, player_id)
  end
end
