defmodule Poker.Accounts do
  alias Poker.Accounts.Commands.{RegisterPlayer}
  alias Poker.Accounts.Projections.{Player}

  def register_player(attrs) do
    player_id = Ecto.UUID.generate()
    command_attrs = Map.put(attrs, :player_id, player_id)

    with {:ok, command} <-
           Poker.Repo.validate_changeset(command_attrs, &RegisterPlayer.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      {:ok, player_id}
    end
  end
end
