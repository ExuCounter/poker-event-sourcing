defmodule Poker.Accounts.Aggregates.Player do
  use Poker, :schema
  alias Poker.Accounts.Aggregates.Player

  embedded_schema do
    field :email, :string
  end

  alias Poker.Accounts.Commands.{RegisterPlayer}
  alias Poker.Accounts.Events.{PlayerRegistered}

  def execute(%Player{}, %RegisterPlayer{} = register) do
    dbg(register.player_uuid)

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
