defmodule Mix.Tasks.Poker.Reset do
  @shortdoc "Resets event store, projections, and runs seeds"
  @moduledoc """
  Resets the entire poker application state and re-seeds.

      mix poker.reset

  This will:
  1. Stop the Commanded app and context supervisors
  2. Reset the event store (drop all events)
  3. Truncate all projection tables (including wallets, cash_games)
  4. Restart the Commanded app and context supervisors
  5. Run seeds to create fresh test data
  """

  use Mix.Task

  @supervised_children [
    Poker.Tables.Supervisor,
    Poker.Wallet.Supervisor,
    Poker.CashGames.Supervisor,
    Poker.Tournaments.Supervisor,
    Poker.App
  ]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("Stopping Commanded app and supervisors...")

    Enum.each(@supervised_children, fn child ->
      Supervisor.terminate_child(Poker.Supervisor, child)
    end)

    IO.puts("Resetting event store and projections...")
    Poker.Storage.reset!()

    IO.puts("Restarting Commanded app and supervisors...")

    Enum.each(Enum.reverse(@supervised_children), fn child ->
      Supervisor.restart_child(Poker.Supervisor, child)
    end)

    IO.puts("Running seeds...")
    Code.eval_file("priv/repo/seeds.exs")

    IO.puts("Done!")
  end
end
