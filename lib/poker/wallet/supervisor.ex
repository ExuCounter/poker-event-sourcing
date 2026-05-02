defmodule Poker.Wallet.Supervisor do
  use Supervisor

  alias Poker.Wallet

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init(
      [
        Wallet.EventHandlers.EventBroadcaster,
        Wallet.Projectors.Wallet
      ],
      strategy: :one_for_one
    )
  end
end
