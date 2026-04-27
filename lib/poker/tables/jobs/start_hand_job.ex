defmodule Poker.Tables.Jobs.StartHandJob do
  use Oban.Worker, queue: :tables, max_attempts: 1

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"table_id" => table_id}}) do
    command = struct(Poker.Tables.Commands.StartHand, %{
      table_id: table_id,
      hand_id: UUIDv7.generate()
    })

    Poker.App.dispatch(command, consistency: :strong)
  end
end
