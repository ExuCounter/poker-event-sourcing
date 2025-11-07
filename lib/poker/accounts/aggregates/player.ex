defmodule Poker.Accounts.Aggregates.Player do
  alias Poker.Accounts.Aggregates.Player
  alias Poker.Accounts.Commands.{RegisterPlayer}
  alias Poker.Accounts.Events.{PlayerRegistered}

  defstruct [:id, :email]

  def execute(%Player{}, %RegisterPlayer{} = register) do
    %PlayerRegistered{
      id: register.player_uuid,
      email: register.email
    }
  end

  # State mutators

  def apply(%Player{} = _player, %PlayerRegistered{} = registered) do
    %Player{
      id: registered.id,
      email: registered.email
    }
  end
end
