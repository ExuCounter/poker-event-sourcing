defmodule Poker.Tournaments.Supervisor do
  use Supervisor

  alias Poker.Tournaments

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init(
      [
        Tournaments.Projectors.Tournament,
        Tournaments.ProcessManager
      ],
      strategy: :one_for_one
    )
  end
end
