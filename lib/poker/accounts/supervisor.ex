defmodule Poker.Accounts.Supervisor do
  use Supervisor

  alias Poker.Accounts

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init(
      [
        Accounts.Projectors.Player
      ],
      strategy: :one_for_one
    )
  end
end
