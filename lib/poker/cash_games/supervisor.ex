defmodule Poker.CashGames.Supervisor do
  use Supervisor

  alias Poker.CashGames

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init(
      [
        CashGames.Projectors.CashGame,
        CashGames.ProcessManager
      ],
      strategy: :one_for_one
    )
  end
end
