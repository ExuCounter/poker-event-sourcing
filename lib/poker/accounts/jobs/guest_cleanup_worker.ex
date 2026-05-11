defmodule Poker.Accounts.Jobs.GuestCleanupWorker do
  @moduledoc """
  Daily job that deletes guest accounts inactive for more than 3 days. Runs
  via Oban.Plugins.Cron — see config/config.exs.
  """

  use Oban.Worker, queue: :accounts, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    deleted = Poker.Accounts.delete_inactive_guests(3)
    {:ok, %{deleted: deleted}}
  end
end
