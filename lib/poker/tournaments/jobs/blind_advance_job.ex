defmodule Poker.Tournaments.Jobs.BlindAdvanceJob do
  use Oban.Worker, queue: :tournaments, max_attempts: 1

  alias Poker.Tournaments.Commands.AdvanceBlindLevel

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tournament_id" => tournament_id, "level" => level}}) do
    command = %AdvanceBlindLevel{tournament_id: tournament_id, level: level}
    Poker.App.dispatch(command, consistency: :strong)
    :ok
  end
end
