defmodule Poker.Tables.Jobs.TimeoutJob do
  use Oban.Worker, queue: :tables, max_attempts: 1

  alias Poker.Tables

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "table_id" => table_id,
          "participant_id" => participant_id,
          "round_id" => round_id
        }
      }) do
    # Dispatch timeout command
    # The aggregate will validate if this is still the correct turn
    Tables.timeout_participant(%{
      table_id: table_id,
      participant_id: participant_id,
      round_id: round_id
    })

    :ok
  end
end
